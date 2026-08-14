# IAP RevenueCat Sync Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix IAP purchase flow so Supabase DB is updated immediately after purchase, credits are granted correctly, and Settings UI shows consistent subscription state.

**Architecture:** Add a new `sync-subscription` Supabase edge function (called post-purchase from Flutter) that verifies entitlements server-side via RevenueCat V2 API and syncs `profiles.is_premium` + credits. Fix `UserProfileCard` to use RevenueCat SDK data (not DB) as source of truth for UI. Invalidate `authViewModelProvider` after sync so DB-dependent state refreshes.

**Tech Stack:** Flutter/Dart, Riverpod (`@riverpod` codegen), Supabase Edge Functions (Deno/TypeScript), RevenueCat V2 REST API, `purchases_flutter` SDK.

---

## Context & Known Facts

- RevenueCat project ID: `proj7a945f6d`
- Entitlement map (stable, hardcode in edge function):
  - `entl0aba27660b` → `ultra` → 500 credits/month
  - `entl2665d1fa2e` → `pro` → 200 credits/month
- `REVENUECAT_SECRET_KEY` and `REVENUECAT_WEBHOOK_SECRET` already set in Supabase secrets
- `grant_subscription_credits` RPC is idempotent via `ON CONFLICT (reference_id) DO NOTHING`
- **Double-grant risk**: webhook uses `event.id` as reference_id; sync uses its own reference_id → both could grant credits. Mitigation: check for existing subscription transaction this billing period before granting.
- `subscription_provider.dart` already imports `authViewModelProvider` → can invalidate directly
- `user_credits` is a view, not a table — it computes balance from transactions, auto-updates via Supabase Realtime stream

---

## Task 1: Create `sync-subscription` Edge Function

**Files:**
- Create: `supabase/functions/sync-subscription/index.ts`

**Step 1: Create the file**

```typescript
// supabase/functions/sync-subscription/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const REVENUECAT_SECRET_KEY = Deno.env.get("REVENUECAT_SECRET_KEY")!;

const RC_PROJECT_ID = "proj7a945f6d";

/** Map RevenueCat entitlement ID → tier name + monthly credits. */
const ENTITLEMENT_MAP: Record<string, { tier: string; credits: number }> = {
    "entl0aba27660b": { tier: "ultra", credits: 500 },
    "entl2665d1fa2e": { tier: "pro", credits: 200 },
};

function getSupabaseClient() {
    return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false },
    });
}

Deno.serve(async (req) => {
    if (req.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed" }), {
            status: 405,
            headers: { "Content-Type": "application/json" },
        });
    }

    // Verify user JWT — get authenticated user ID from Supabase auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
        return new Response(JSON.stringify({ error: "Missing authorization" }), {
            status: 401,
            headers: { "Content-Type": "application/json" },
        });
    }

    // Use anon client to verify JWT
    const userClient = createClient(
        SUPABASE_URL,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { auth: { persistSession: false }, global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
            status: 401,
            headers: { "Content-Type": "application/json" },
        });
    }

    try {
        const supabase = getSupabaseClient();
        const userId = user.id;

        // 1. Get revenuecat_app_user_id from profile
        const { data: profile, error: profileErr } = await supabase
            .from("profiles")
            .select("revenuecat_app_user_id")
            .eq("id", userId)
            .maybeSingle();

        if (profileErr || !profile?.revenuecat_app_user_id) {
            console.error("[sync-subscription] Profile not found or RC ID missing:", userId);
            return new Response(JSON.stringify({ error: "Profile not linked to RevenueCat" }), {
                status: 400,
                headers: { "Content-Type": "application/json" },
            });
        }

        const rcUserId = profile.revenuecat_app_user_id;

        // 2. Fetch active entitlements from RevenueCat V2 API
        const rcRes = await fetch(
            `https://api.revenuecat.com/v2/projects/${RC_PROJECT_ID}/customers/${rcUserId}/active_entitlements`,
            {
                headers: {
                    "Authorization": `Bearer ${REVENUECAT_SECRET_KEY}`,
                    "Content-Type": "application/json",
                },
            },
        );

        if (!rcRes.ok) {
            const body = await rcRes.text();
            console.error("[sync-subscription] RevenueCat API error:", rcRes.status, body);
            return new Response(JSON.stringify({ error: "RevenueCat API error" }), {
                status: 502,
                headers: { "Content-Type": "application/json" },
            });
        }

        const rcData = await rcRes.json() as {
            items: Array<{ entitlement_id: string; expires_at: number }>;
        };

        // 3. Determine highest tier from active entitlements
        // Priority: ultra > pro > free
        let resolvedTier: string | null = null;
        let resolvedCredits = 0;
        let resolvedExpiresAt: string | null = null;

        // Check ultra first, then pro
        const tierPriority = ["entl0aba27660b", "entl2665d1fa2e"];
        for (const entitlementId of tierPriority) {
            const match = rcData.items.find((e) => e.entitlement_id === entitlementId);
            if (match) {
                const info = ENTITLEMENT_MAP[entitlementId];
                resolvedTier = info.tier;
                resolvedCredits = info.credits;
                resolvedExpiresAt = match.expires_at
                    ? new Date(match.expires_at).toISOString()
                    : null;
                break;
            }
        }

        const isPremium = resolvedTier !== null;

        // 4. Update subscription status in profiles
        const { error: statusErr } = await supabase.rpc("update_subscription_status", {
            p_user_id: userId,
            p_is_premium: isPremium,
            p_tier: resolvedTier,
            p_expires_at: resolvedExpiresAt,
        });

        if (statusErr) {
            console.error("[sync-subscription] update_subscription_status error:", statusErr);
            return new Response(JSON.stringify({ error: "Failed to update subscription status" }), {
                status: 500,
                headers: { "Content-Type": "application/json" },
            });
        }

        // 5. Grant credits if active subscription AND not already granted this billing period
        if (isPremium && resolvedCredits > 0) {
            const billingPeriodStart = new Date();
            billingPeriodStart.setDate(billingPeriodStart.getDate() - 30);

            const { data: existing } = await supabase
                .from("credit_transactions")
                .select("id")
                .eq("user_id", userId)
                .eq("type", "subscription")
                .gte("created_at", billingPeriodStart.toISOString())
                .maybeSingle();

            if (!existing) {
                const referenceId = `rc-sync-${userId}-${resolvedExpiresAt ?? "unlimited"}`;
                const { error: creditErr } = await supabase.rpc("grant_subscription_credits", {
                    p_user_id: userId,
                    p_amount: resolvedCredits,
                    p_description: `${resolvedTier} subscription — sync`,
                    p_reference_id: referenceId,
                });

                if (creditErr) {
                    console.error("[sync-subscription] grant_subscription_credits error:", creditErr);
                    // Non-fatal: subscription status already updated
                }
            }
        }

        console.log(
            `[sync-subscription] Synced user ${userId}: tier=${resolvedTier ?? "free"}, premium=${isPremium}`
        );

        return new Response(
            JSON.stringify({
                ok: true,
                tier: resolvedTier,
                is_premium: isPremium,
                expires_at: resolvedExpiresAt,
            }),
            { status: 200, headers: { "Content-Type": "application/json" } },
        );
    } catch (error) {
        console.error("[sync-subscription] Unexpected error:", error);
        return new Response(JSON.stringify({ error: "Internal server error" }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
        });
    }
});
```

**Step 2: Deploy edge function**

```bash
cd /Users/mini4/1space/artio
supabase functions deploy sync-subscription --project-ref kytbmplsazsiwndppoji
```

Expected: `✓ sync-subscription deployed`

**Step 3: Smoke test edge function with curl**

```bash
# Get a valid JWT first (sign in via supabase or use existing session token from app)
# Then test:
curl -s -X POST \
  "https://kytbmplsazsiwndppoji.supabase.co/functions/v1/sync-subscription" \
  -H "Authorization: Bearer <USER_JWT>" \
  -H "Content-Type: application/json" | python3 -m json.tool
```

Expected response:
```json
{
    "ok": true,
    "tier": "ultra",
    "is_premium": true,
    "expires_at": "..."
}
```

**Step 4: Commit**

```bash
git add supabase/functions/sync-subscription/index.ts
git commit -m "feat(iap): add sync-subscription edge function for post-purchase DB sync

Calls RevenueCat V2 API server-side to verify entitlements, then:
- Updates profiles.is_premium + subscription_tier immediately
- Grants credits if not already granted in current billing period
- Idempotent: checks for existing subscription transaction before granting"
```

---

## Task 2: Update `SubscriptionNotifier` to Sync After Purchase/Restore

**Files:**
- Modify: `lib/features/subscription/presentation/providers/subscription_provider.dart`

**Context:** This file already imports `authViewModelProvider`. Need to add Supabase client import to call edge function.

**Step 1: Add import for Supabase provider + Log**

At top of file, add:
```dart
import 'package:artio/core/providers/supabase_provider.dart';
import 'package:artio/utils/logger_service.dart';
```

**Step 2: Add `_syncToSupabase()` private method and update `purchase()` + `restore()`**

Replace the full file content:

```dart
import 'package:artio/core/providers/supabase_provider.dart';
import 'package:artio/features/auth/presentation/state/auth_state.dart';
import 'package:artio/features/auth/presentation/view_models/auth_view_model.dart';
import 'package:artio/features/subscription/domain/entities/subscription_package.dart';
import 'package:artio/features/subscription/domain/entities/subscription_status.dart';
import 'package:artio/features/subscription/domain/providers/subscription_repository_provider.dart';
import 'package:artio/utils/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscription_provider.g.dart';

@riverpod
class SubscriptionNotifier extends _$SubscriptionNotifier {
  @override
  Future<SubscriptionStatus> build() async {
    // Admin/DB-premium users bypass RevenueCat and get Ultra status.
    final authState = ref.watch(authViewModelProvider);
    final isDbPremium = switch (authState) {
      AuthStateAuthenticated(user: final u) => u.isPremium,
      _ => false,
    };
    if (isDbPremium) {
      return const SubscriptionStatus(
        tier: SubscriptionTiers.ultra,
        isActive: true,
        willRenew: true,
      );
    }

    final repo = ref.watch(subscriptionRepositoryProvider);
    return repo.getStatus();
  }

  /// Purchase a subscription package, sync to Supabase, and update state.
  Future<void> purchase(SubscriptionPackage package) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(subscriptionRepositoryProvider);
      final result = await repo.purchase(package);
      await _syncToSupabase();
      return result;
    });
  }

  /// Restore previous purchases, sync to Supabase, and update state.
  Future<void> restore() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(subscriptionRepositoryProvider);
      final result = await repo.restore();
      await _syncToSupabase();
      return result;
    });
  }

  /// Call sync-subscription edge function then refresh auth state.
  /// Non-blocking: errors are logged but never surface to user.
  Future<void> _syncToSupabase() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.functions.invoke('sync-subscription');
      // Refresh auth state so UserProfileCard picks up new is_premium from DB.
      ref.invalidate(authViewModelProvider);
    } on Object catch (e) {
      Log.w('sync-subscription failed (non-blocking): $e');
    }
  }
}

/// Provider for available subscription offerings.
@riverpod
Future<List<SubscriptionPackage>> offerings(Ref ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getOfferings();
}
```

**Step 3: Run codegen** (needed after touching `@riverpod` files)

```bash
cd /Users/mini4/1space/artio
dart run build_runner build --delete-conflicting-outputs
```

Expected: no errors, `subscription_provider.g.dart` regenerated.

**Step 4: Run static analysis**

```bash
flutter analyze lib/features/subscription/
```

Expected: `No issues found!`

**Step 5: Commit**

```bash
git add lib/features/subscription/presentation/providers/subscription_provider.dart
git add lib/features/subscription/presentation/providers/subscription_provider.g.dart
git commit -m "feat(iap): sync subscription to Supabase after purchase/restore

After RevenueCat confirms purchase, calls sync-subscription edge function
to immediately update profiles.is_premium + grant credits server-side.
Invalidates authViewModelProvider so UI reflects new DB state."
```

---

## Task 3: Fix `UserProfileCard` to Use RevenueCat Data

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`

**Problem:** Line 124–127 reads `isPremium` from `user.isPremium` (Supabase DB, slow). Should fall back to `subscriptionNotifierProvider` (RevenueCat SDK, immediate) first.

**Step 1: Add watch for subscriptionNotifierProvider in `build()`**

In `settings_screen.dart`, in the `build()` method, add one line after the existing auth state watches:

Find this block (around line 115–127):
```dart
final authState = ref.watch(authViewModelProvider);
final isLoggedIn = authState.maybeMap(
  authenticated: (_) => true,
  orElse: () => false,
);
final email = authState.maybeMap(
  authenticated: (s) => s.user.email,
  orElse: () => '',
);
final isPremium = authState.maybeMap(
  authenticated: (s) => s.user.isPremium,
  orElse: () => false,
);
```

Replace with:
```dart
final authState = ref.watch(authViewModelProvider);
final subStatus = ref.watch(subscriptionNotifierProvider);
final isLoggedIn = authState.maybeMap(
  authenticated: (_) => true,
  orElse: () => false,
);
final email = authState.maybeMap(
  authenticated: (s) => s.user.email,
  orElse: () => '',
);
// Prefer RevenueCat SDK data (immediate) over DB value (webhook-dependent).
// Falls back to DB if RevenueCat hasn't loaded yet.
final isPremium = subStatus.valueOrNull?.isActive ??
    authState.maybeMap(
      authenticated: (s) => s.user.isPremium,
      orElse: () => false,
    );
```

**Step 2: Add missing import** at top of `settings_screen.dart`:
```dart
import 'package:artio/core/state/subscription_state_provider.dart';
```

**Step 3: Run static analysis**

```bash
flutter analyze lib/features/settings/
```

Expected: `No issues found!`

**Step 4: Commit**

```bash
git add lib/features/settings/presentation/settings_screen.dart
git commit -m "fix(ui): use RevenueCat SDK data for UserProfileCard premium badge

Previously used user.isPremium (DB field) which only updates after webhook.
Now prefers subscriptionNotifierProvider (RevenueCat SDK, immediate) with
DB value as fallback while SDK loads. Fixes FREE PLAN/ULTRA PLAN inconsistency."
```

---

## Task 4: Add `subscriptionNotifierProvider` to Logout Invalidation

**Files:**
- Modify: `lib/core/state/user_scoped_providers.dart`

**Problem:** On logout, `subscriptionNotifierProvider` is not invalidated → stale RevenueCat state from previous user could leak to next login.

**Step 1: Add import + invalidation**

Find the existing file:
```dart
import 'package:artio/core/state/credit_balance_state_provider.dart';
import 'package:artio/features/create/presentation/providers/create_form_provider.dart';
// ... other imports

void invalidateUserScopedProviders(Ref ref) {
  ref
    ..invalidate(galleryStreamProvider)
    ..invalidate(galleryActionsNotifierProvider)
    ..invalidate(templatesProvider)
    ..invalidate(generationViewModelProvider)
    ..invalidate(createViewModelProvider)
    ..invalidate(createFormNotifierProvider)
    ..invalidate(creditBalanceNotifierProvider);
}
```

Add `subscriptionNotifierProvider` import and invalidation:
```dart
import 'package:artio/core/state/credit_balance_state_provider.dart';
import 'package:artio/core/state/subscription_state_provider.dart';   // ADD
import 'package:artio/features/create/presentation/providers/create_form_provider.dart';
// ... other imports

void invalidateUserScopedProviders(Ref ref) {
  ref
    ..invalidate(galleryStreamProvider)
    ..invalidate(galleryActionsNotifierProvider)
    ..invalidate(templatesProvider)
    ..invalidate(generationViewModelProvider)
    ..invalidate(createViewModelProvider)
    ..invalidate(createFormNotifierProvider)
    ..invalidate(creditBalanceNotifierProvider)
    ..invalidate(subscriptionNotifierProvider);  // ADD
}
```

**Step 2: Run static analysis**

```bash
flutter analyze lib/core/state/
```

Expected: `No issues found!`

**Step 3: Run full analysis**

```bash
flutter analyze
```

Expected: `No issues found!`

**Step 4: Commit**

```bash
git add lib/core/state/user_scoped_providers.dart
git commit -m "fix(auth): invalidate subscriptionNotifierProvider on logout

Prevents stale RevenueCat subscription state from leaking between
user sessions when logging out and back in with a different account."
```

---

## Task 5: End-to-End Verification on Device

**Step 1: Build and run on SM-A536E (WiFi ADB)**

```bash
flutter run \
  --dart-define=ENV=development \
  -d 192.168.1.25:45305
```

**Step 2: Watch logcat for sync-subscription calls**

In a separate terminal:
```bash
adb -s 192.168.1.25:45305 logcat | grep -i -E "(sync.subscription|revenuecat|purchase|credit|flutter)"
```

**Step 3: Test purchase flow**

1. Login with a **different** test account (not sadotmask — that one was manually fixed)
2. Go to Settings → verify "FREE PLAN" + 0 credits
3. Go to Paywall → buy Pro or Ultra
4. Expected after purchase:
   - SnackBar: "🎉 Subscription activated!"
   - Settings → `UserProfileCard` shows **PREMIUM** badge
   - Settings → `SubscriptionCard` shows **PRO/ULTRA Plan**
   - Credits show **200/500** (not 0)
5. Force-close app and reopen → state should persist

**Step 4: Test restore flow**

1. Logout → Login with same account
2. Go to Paywall → tap "Restore Purchases"
3. Expected: subscription restored, DB synced, credits visible

**Step 5: Verify Supabase DB was updated**

```bash
# Replace EMAIL with test account email
curl -s "https://kytbmplsazsiwndppoji.supabase.co/rest/v1/profiles?email=eq.EMAIL&select=is_premium,subscription_tier,free_credits,purchased_credits" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5dGJtcGxzYXpzaXduZHBwb2ppIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTA0MTI5MSwiZXhwIjoyMDg2NjE3MjkxfQ.ItnOIiw6NB39PIeyQlE-OJ-AwSKnO_qUuel2_obc590" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5dGJtcGxzYXpzaXduZHBwb2ppIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTA0MTI5MSwiZXhwIjoyMDg2NjE3MjkxfQ.ItnOIiw6NB39PIeyQlE-OJ-AwSKnO_qUuel2_obc590" | python3 -m json.tool
```

Expected: `"is_premium": true`, `"subscription_tier": "pro"` or `"ultra"`

---

## Task 6 (Manual — User Action): Configure RevenueCat Webhook

**This task requires access to RevenueCat Dashboard — cannot be automated.**

**Step 1: Get webhook secret value**

Go to Supabase Dashboard → Edge Functions → Secrets → copy value of `REVENUECAT_WEBHOOK_SECRET`.

**Step 2: Configure webhook in RevenueCat**

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com) → Project **ARTIO**
2. Navigate to: **Project Settings → Integrations → Webhooks**
3. Click **Add Webhook**
4. Set:
   - **URL:** `https://kytbmplsazsiwndppoji.supabase.co/functions/v1/revenuecat-webhook`
   - **Authorization header:** `Bearer <REVENUECAT_WEBHOOK_SECRET value>`
5. Save and **Send Test Event**

**Step 3: Verify test event received**

Check Supabase Dashboard → Edge Functions → Logs for `revenuecat-webhook`. Should show a log entry from the test event.

**Why this is still needed (even after sync-subscription):**
- `sync-subscription` handles immediate post-purchase sync
- Webhook handles: renewals, cancellations, expirations — events that happen without user interaction
- Both together = complete coverage

---

## Summary

| Task | Type | Risk |
|------|------|------|
| 1. `sync-subscription` edge function | New code | Low — server-side only |
| 2. Call sync after purchase/restore | Modify Flutter | Low — non-blocking, errors logged |
| 3. Fix `UserProfileCard` data source | Modify Flutter | Very low — 3-line change |
| 4. Invalidate sub on logout | Modify Flutter | Very low — 1-line add |
| 5. E2E verify on device | Testing | — |
| 6. Configure RevenueCat webhook | Manual | — |

**After all tasks:** New users who purchase will have DB updated immediately (sync-subscription), and all future renewals/cancellations will be handled via webhook.
