---
name: iap-revenuecat
description: Use when setting up In-App Purchase with RevenueCat for Flutter + Google Play, wiring Supabase edge functions for purchase verification and webhook events, debugging credits not granted, subscription tier not updating, JWT 401 errors from edge functions, double-grant race conditions, or webhook auth failures.
---

# IAP + RevenueCat Setup Skill

> **Last Updated:** 2026-03-28 (Production-verified on Artio app — E2E confirmed 4 test accounts)
> **Stack:** Flutter + RevenueCat + Google Play + Supabase Edge Functions

---

## 🗺️ Overview Architecture

```
Flutter App
  └── RevenueCat SDK (goog_xxx key)
        └── Google Play Billing
              └── Purchase success
                    ├── [Immediate] verify-google-purchase edge fn → grant credits ONLY (no tier update)
                    └── [Async]     RC server → RC Webhook → Supabase revenuecat-webhook fn
                                          ↑
                              Requires: Pub/Sub + RTDN configured correctly
```

> **Design principle:** `verify-google-purchase` = immediate fallback for UI feedback.
> `revenuecat-webhook` = authoritative source when RC pipeline is stable.

---

## ⚠️ CRITICAL GOTCHAS (Read FIRST)

### 1. API Access in Google Play Console REMOVED (2024+)
- **Old way:** Settings → API access → Link Google Cloud project
- **New way (2024+):** Go to **Users & Permissions → Invite new users** → paste service account email
- If you navigate to `/apiAccess` URL → redirects to home = permission issue or feature removed

### 2. Service Account Key Creation Disabled (Google Workspace)
- Google Workspace orgs + new projects auto-enforce `iam.disableServiceAccountKeyCreation`
- **Fix:** Use a personal `@gmail.com` account to create a NEW Google Cloud project
- Personal Gmail does not inherit org policies
- Then invite that service account email into Google Play Console

### 3. Package Name Must Match EXACTLY
- RevenueCat package name must match `applicationId` in `android/app/build.gradle.kts`
- The package name used during Google Play app creation is permanent — cannot change
- Common mistake: `com.company.app` vs `com.company.appname` — check carefully

### 4. Service Account Propagation Delay
- After inviting service account to Play Console → wait UP TO 24 HOURS
- RevenueCat will show "Credentials need attention" during this period → normal
- Do not delete and recreate — just wait

### 5. RevenueCat Key Types
- `goog_xxx` = Public (client-side) key for Flutter SDK
- Service Account JSON = Server credential for RevenueCat to verify purchases
- **Both are required** — different purpose

### 6. Webhook Auth Header Format — Raw Token, NO `Bearer` Prefix
- RevenueCat sends the Authorization header value **EXACTLY as configured in the RC Dashboard** — it does NOT auto-add `"Bearer "`.
- Store only the raw token in `REVENUECAT_WEBHOOK_SECRET`. Compare `authHeader` directly against the secret — **no prefix construction**.
- ⚠️ **If you use `\`Bearer \${secret}\`` the comparison will never match** → every webhook event returns 401 → RC retries forever.

```typescript
// ✅ CORRECT — raw token, no Bearer prefix
const expectedAuth = REVENUECAT_WEBHOOK_SECRET;

// ❌ WRONG — adds Bearer prefix RC never sends
const expectedAuth = `Bearer ${REVENUECAT_WEBHOOK_SECRET}`;
```

- Use timing-safe comparison (XOR loop, not `crypto.subtle.timingSafeEqual` — see Gotcha #11)
- **To verify auth is working:** `curl -X POST -H "Authorization: <raw-token>" -H "Content-Type: application/json" -d '{}' <webhook-url>` → `200 {"ok":true}` = auth OK (empty body soft-ignored); `401` = token mismatch.

### 7. AAB Rebuild Required After .env Changes
- `.env` files are Flutter assets → bundled into APK/AAB
- Changing any key in `.env.*` requires full rebuild + new upload to Play Store

### 8. 🆕 JWT Algorithm Mismatch: ES256 vs HS256 (PRODUCTION BUG)
> **Root cause confirmed in production (2026-03-12)**

**Problem:** Supabase Edge Functions deployed with default `verify_jwt=true` will **reject** all Flutter app JWTs with `{"code":401,"message":"Invalid JWT"}`.

**Why:** GoTrue v2 (Supabase auth) issues JWTs signed with **ES256** (asymmetric). The Supabase API gateway's built-in JWT verification checks for **HS256** (symmetric with `JWT_SECRET`). Algorithm mismatch → every request rejected.

**Symptom:** Flutter app calls edge function → gets `FunctionException` silently swallowed → edge function never runs → no DB updates, no credits.

**Fix:** Deploy ALL edge functions with `--no-verify-jwt` flag and implement JWT auth manually inside:
```bash
# CORRECT deployment:
supabase functions deploy YOUR-FUNCTION --no-verify-jwt --project-ref YOUR_REF

# WRONG (default) — will reject Flutter app JWTs:
supabase functions deploy YOUR-FUNCTION  # implicitly --verify-jwt=true
```

**Manual JWT auth pattern (inside edge function):**
```typescript
const authHeader = req.headers.get("Authorization");
if (!authHeader) return new Response(JSON.stringify({ error: "Missing authorization" }), { status: 401 });

const userClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
  auth: { persistSession: false },
  global: { headers: { Authorization: authHeader } },
});
const { data: { user }, error } = await userClient.auth.getUser();
if (error || !user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
```

### 9. 🆕 StoreTransaction.transactionIdentifier = orderId, NOT purchaseToken
> **Confirmed in purchases_flutter 9.x (Android)**

- `result.storeTransaction.transactionIdentifier` = Google Play **orderId** (`GPA.xxxx-xxxx-xxxx-xxxxx`)
- This is NOT the `purchaseToken` required by Google Play Developer API
- Consequence: Cannot call `/androidpublisher/v3/.../purchases/subscriptions/{id}/tokens/{token}` from Supabase — you don't have the real token
- **Design decision:** Trust RC client-side validation. Use orderId as idempotency key only.
- orderId can be **empty** for subscriptions with free trials → when empty, **skip verify call entirely** (RC webhook INITIAL_PURCHASE handles credits) — see Gotcha #17

### 11. 🆕 `crypto.subtle.timingSafeEqual` Not Available in Supabase Edge Runtime
> **Root cause confirmed in production (2026-03-14)**

**Problem:** `crypto.subtle.timingSafeEqual` is a Deno extension to the Web Crypto API — it is **not implemented** in Supabase's Edge Runtime. Calling it throws `TypeError: crypto.subtle.timingSafeEqual is not a function` → the catch block returns 500 → RevenueCat retries indefinitely.

**Wrong code (will crash):**
```typescript
const isValid = await crypto.subtle.timingSafeEqual(
  encoder.encode(authHeader),
  encoder.encode(expectedAuth)
);
```

**Fix — manual constant-time XOR loop:**
```typescript
const encoder = new TextEncoder();
const a = encoder.encode(authHeader ?? "");
const b = encoder.encode(expectedAuth);
let diff = a.length ^ b.length;
const len = Math.min(a.length, b.length);
for (let i = 0; i < len; i++) diff |= a[i] ^ b[i];
const authValid = authHeader !== null && diff === 0;
```
This is constant-time: always iterates `min(a.length, b.length)` bytes regardless of mismatch position.

---

### 12. 🆕 signUp Race Condition — `revenuecat_app_user_id` = NULL for New Users
> **Root cause confirmed in production (2026-03-14)**

**Problem:** Calling `_revenuecatLogIn()` (which UPDATEs `profiles.revenuecat_app_user_id`) BEFORE `_createUserProfile()` (which INSERTs the profile row) → UPDATE matches 0 rows → silent fail → `revenuecat_app_user_id` stays NULL → RC webhook lookup fails → webhook returns 500 → RC retries forever.

**Wrong order:**
```dart
await _revenuecatLogIn(response.user!.id);   // UPDATE runs — 0 rows exist yet
await _createUserProfile(response.user!.id, email);  // INSERT — rc_id not set
```

**Fix — INSERT first, then UPDATE:**
```dart
// 1. Create profile first
await _createUserProfile(response.user!.id, email);
// 2. Then link RC (UPDATE now finds the row)
await _revenuecatLogIn(response.user!.id);
```

**Belt-and-suspenders: also include `revenuecat_app_user_id` in the INSERT itself:**
```dart
await _supabase.from('profiles').insert({
  'id': userId,
  'email': email,
  'is_premium': false,
  'revenuecat_app_user_id': userId,  // ← set immediately, don't rely on UPDATE
  'created_at': DateTime.now().toIso8601String(),
});
```
Same fix applies to `fetchOrCreateProfile` for Google/Apple OAuth users.

---

### 13. 🆕 `p_tier: null` Writes NULL to DB — Pass `'free'` Explicitly
> **Confirmed in production (2026-03-14)**

**Problem:** `update_subscription_status` RPC does `SET subscription_tier = p_tier`. If you pass `p_tier: null`, the column is set to NULL — the column default `'free'` only applies on INSERT, not UPDATE.

**Wrong:**
```typescript
await supabase.rpc("update_subscription_status", {
  p_user_id: userId,
  p_is_premium: false,
  p_tier: null,       // ← writes NULL, not 'free'
  p_expires_at: null,
});
```

**Fix:**
```typescript
p_tier: "free",   // explicit string, not null
```
Always pass `"free"` for EXPIRATION and downgrade events.

---

### 14. 🆕 Module-Level Throws Cause BOOT_ERROR (503) on Every Request
> **Confirmed in production (2026-03-14)**

**Problem:** Throwing an error at module initialization level (outside `Deno.serve()`) causes the entire edge function to fail to start. Every subsequent request gets `503 Service Unavailable` with body `{"code":"BOOT_ERROR"}`.

**Wrong:**
```typescript
const RC_PROJECT_ID = Deno.env.get("REVENUECAT_PROJECT_ID");
if (!RC_PROJECT_ID) throw new Error("REVENUECAT_PROJECT_ID env var is required");
// ↑ This runs at import time → BOOT_ERROR on every request
```

**Fix — validate inside the handler:**
```typescript
Deno.serve(async (req) => {
  const RC_PROJECT_ID = Deno.env.get("REVENUECAT_PROJECT_ID");
  if (!RC_PROJECT_ID) {
    console.error("REVENUECAT_PROJECT_ID not set");
    return new Response(JSON.stringify({ error: "Server misconfigured" }), { status: 500 });
  }
  // ... rest of handler
});
```

**Required secret for sync-subscription:**
```bash
supabase secrets set REVENUECAT_PROJECT_ID=<your-rc-project-id> --project-ref YOUR_REF
# Find project ID in RC Dashboard URL: app.revenuecat.com/projects/<PROJECT_ID>/...
```

---

### 15. 🆕 Double-Grant Prevention: `p_check_recent_grant` Parameter
> **Production-verified on Artio (2026-03-28)**

**Problem:** `verify-google-purchase` and `revenuecat-webhook` INITIAL_PURCHASE can both fire within seconds of a purchase, granting credits twice. They use different `reference_id` formats (`gp-GPA.xxx` vs event UUID) so `ON CONFLICT(reference_id)` alone cannot dedup them.

**Fix:** Pass `p_check_recent_grant: true` to `grant_subscription_credits`. This moves the 25-day per-user guard INSIDE the RPC, under `pg_advisory_xact_lock` — atomic, no TOCTOU race.

```typescript
// INITIAL_PURCHASE — use p_check_recent_grant=true
await supabase.rpc("grant_subscription_credits", {
  p_user_id: userId,
  p_amount: credits,
  p_reference_id: referenceId,
  p_check_recent_grant: true,   // ← 25-day guard runs atomically inside RPC
});

// RENEWAL — use p_check_recent_grant=false
// Renewal events have unique event IDs — ON CONFLICT(reference_id) handles dedup.
// Rate-limiting RENEWAL would break legitimate monthly credit grants.
await supabase.rpc("grant_subscription_credits", {
  p_reference_id: eventId,
  p_check_recent_grant: false,
});
```

**RPC return value:** `{ granted: boolean, reason: string | null }`
- `granted: true` → credits granted
- `granted: false, reason: "recent_grant_exists"` → already granted this cycle (25-day guard triggered)
- `granted: false, reason: "duplicate_reference_id"` → same reference_id seen before (ON CONFLICT)

**Rule:** The guard MUST run inside the RPC. Never re-add it as an external SELECT check in edge functions — that reintroduces the TOCTOU race.

---

### 16. 🆕 sync-subscription: 5-Minute Race Condition Guard
> **Production-verified on Artio (2026-03-28)**

**Problem:** After purchase, `verify-google-purchase` sets `is_premium=true` in the DB immediately. The app then calls `sync-subscription` to sync RC entitlements. But RC may not yet know about the purchase (Pub/Sub latency, usually <5s but can be longer). If RC returns 0 active entitlements, a naive `sync-subscription` would immediately downgrade the user — undoing the successful purchase.

**Fix:** Skip downgrade if the profile was set premium within the last 5 minutes:
```typescript
if (!isPremium) {
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
  const isRecentlyUpdated = profile?.is_premium === true
    && new Date(profile.updated_at) > fiveMinutesAgo;
  if (isRecentlyUpdated) {
    // RC still processing — trust verify-google-purchase result
    return { synced: false, reason: "rc_processing_in_flight" };
  }
  // > 5 min: RC is authoritative — downgrade
}
```

---

### 17. 🆕 Empty orderId → Skip verify, Never Use Timestamp Fallback
> **Production-verified on Artio (2026-03-28)**

**Problem:** `StoreTransaction.transactionIdentifier` can be empty for free trial subscriptions (orderId not yet assigned by Google). Old approach used timestamp-based fallback tokens (`rc-{productId}-{Date.now()}`). **This is a security hole** — any authenticated user can call the edge function with an arbitrary timestamp to bypass the GPA format validation and claim credits repeatedly.

**Fix:**
```dart
final rawToken = result.storeTransaction.transactionIdentifier;
if (rawToken.isNotEmpty) {
  unawaited(_verifyWithGooglePlay(rawToken, productId));
} else {
  // Skip immediate verify — RC webhook INITIAL_PURCHASE will handle credits
  Log.w('[RC] orderId empty (free trial?) — skipping verify, RC webhook will handle credits');
}
```

**In the edge function:** Only accept `GPA.XXXX-XXXX-XXXX-XXXXX` format. Reject anything else with 400. Do NOT accept timestamp-based fallbacks.

---

### 10. 🆕 RC Webhook Requires Pub/Sub — Not Just Webhook URL
Setting webhook URL in RC Dashboard is NOT enough for Google Play events to reach your server.

**Full RTDN pipeline required:**
```
Google Play → Cloud Pub/Sub topic → RC subscribes → RC processes → RC fires your webhook
```

**Setup steps:**
1. Google Cloud Console → Enable Cloud Pub/Sub API
2. Create topic: `projects/{project-id}/topics/{topic-name}`
3. Grant service account Pub/Sub Admin at project level
4. RC Dashboard → Play Store → Real-time developer notifications → paste topic name
5. Google Play Console → Monetization setup → paste same topic name → Send test notification
6. Verify RC Dashboard shows "Connected to Google ✅"

**Common failure:** RC Dashboard shows topic configured but "No notifications received" → Pub/Sub subscription created by RC hasn't activated yet. Wait 15-30 min after initial setup.

---

## 📋 Step-by-Step Setup (2024-2026)

### PHASE 1: Google Play Console

#### 1.1 Create app
- Application ID (package name) — set once, cannot change
- Upload first AAB → must be **release-signed** (not debug)
- Create release keystore: `keytool -genkey -v -keystore app.jks -keyalg RSA -keysize 2048 -validity 10000`

#### 1.2 Create Subscription Products
- Monetize → Subscriptions → Create subscription
- ID format: `appname_tier_period` (e.g., `artio_pro_monthly`)
- Add base plan → set billing period → add pricing
- Status must be **Active** before RevenueCat can fetch

#### 1.3 Internal Testing Track
- Testing → Internal testing → Create release → Upload AAB
- Add tester emails
- Add test Gmail to **Settings → License testing** (critical for sandbox purchases!)

---

### PHASE 2: Google Cloud Console + Service Account

#### 2.1 Create Google Cloud Project
```
# Use personal @gmail.com account (avoids Workspace org policy restrictions)
1. console.cloud.google.com → New Project → name: "appname-revenuecat"
2. APIs & Services → Enable → "Google Play Android Developer API"
3. APIs & Services → Enable → "Cloud Pub/Sub API"  ← Required for RC RTDN
```

#### 2.2 Create Service Account
```
IAM & Admin → Service Accounts → Create service account
  Name: revenuecat-appname
  Role: Pub/Sub Admin  ← Required for RC to create Pub/Sub subscriptions
  → Create and continue → Done
```

#### 2.3 Download JSON Key
```
Click service account → Keys tab → Add Key → Create new key → JSON
→ Download file (keep safe, never commit to git!)
```

**If "Key creation disabled" error:**
```bash
# Via gcloud CLI:
gcloud iam service-accounts keys create ./service-account.json \
  --iam-account=SERVICE_ACCOUNT_EMAIL \
  --project=PROJECT_ID

# Or override org policy (if you own the project):
# IAM & Admin → Organization Policies → iam.disableServiceAccountKeyCreation
# → Override parent → Set enforcement: OFF → Save
```

---

### PHASE 3: Link Service Account to Play Console

**2024+ method (API access page removed):**
```
Google Play Console → Users and permissions → Invite new users
  Email: service-account-name@project-id.iam.gserviceaccount.com
  Permissions:
    ✅ View financial data, orders, and cancellation survey responses
    ✅ Manage orders and subscriptions
→ Invite user → Done
```

> Note: Takes up to 24h to propagate

---

### PHASE 4: RevenueCat Dashboard

#### 4.1 App Setup
```
app.revenuecat.com → New App → Android (Play Store)
  App name: [Your App Name]
  Google Play package name: com.your.app  ← MUST match build.gradle applicationId
  Service Account Credentials JSON: upload file from Phase 2.3
```

#### 4.2 Connect Real-Time Developer Notifications (RTDN)
```
RC Dashboard → App → Google Play → Real-time developer notifications
  Topic: projects/{project-id}/topics/{topic-name}
  → Save → Status should show "Connected to Google ✅"
```

Then in Google Play Console:
```
Monetize → Monetization setup → Real-time developer notifications
  Topic name: projects/{project-id}/topics/{topic-name}  ← same topic
  → Send test notification → verify RC Dashboard notification counter increases
```

#### 4.3 Products
```
Product catalog → Products → Import Products (button)
  If import fails (credentials not active yet):
    → New product manually:
    Display name: Artio Pro Monthly
    Product type: Subscription
    Subscription: artio_pro_monthly  ← Google Play subscription ID
    Base plan Id: artio-pro-monthly  ← Base plan ID from Google Play
    Backwards compatible: ✅
```

#### 4.4 Entitlements
```
Product catalog → Entitlements → + New
  pro:   attach artio_pro_monthly, artio_pro_yearly
  ultra: attach artio_ultra_monthly, artio_ultra_yearly
```

#### 4.5 Offerings — mark one as "Current"
```
Product catalog → Offerings → default → Packages tab
  Monthly:       $rc_monthly     → link Pro Monthly product
  Yearly:        $rc_annual      → link Pro Yearly product
  Ultra Monthly: (custom)        → link Ultra Monthly product

  ⚠️ Mark one offering as "Current" — Purchases.getOfferings().current returns null otherwise!
```

#### 4.6 API Keys
```
RevenueCat → Project settings → API Keys
  Android: goog_xxxxxxxxxxxx  → add to .env as REVENUECAT_GOOGLE_KEY
  iOS:     appl_xxxxxxxxxxxx  → add to .env as REVENUECAT_APPLE_KEY
```

---

### PHASE 5: Supabase Edge Functions

#### 5.1 verify-google-purchase (immediate credit grant)
Called by app right after `Purchases.purchase()` succeeds. Grants credits immediately without waiting for RC webhook.

**⚠️ Security design decisions (MUST understand before modifying):**
- `update_subscription_status` is **intentionally omitted** — `productId` is client-supplied, so setting tier from it before verifying ownership would allow tier escalation (e.g., claiming `ultra` with a `pro` purchaseToken).
- Timestamp-based fallback tokens (`rc-...-{unixMs}`) are **removed** — any authenticated user could forge them with arbitrary timestamps to repeatedly claim credits.
- The RC webhook sets the authoritative tier + expiry within seconds of purchase.

```typescript
// supabase/functions/verify-google-purchase/index.ts
// Deploy: supabase functions deploy verify-google-purchase --no-verify-jwt

/** Map product ID prefix → tier name + credits */
function getTierInfo(productId: string): { tier: string; credits: number } | null {
  if (productId.startsWith("appname_ultra_")) return { tier: "ultra", credits: 500 };
  if (productId.startsWith("appname_pro_"))  return { tier: "pro",   credits: 200 };
  return null;
}

/**
 * 🔒 SECURITY: Accept ONLY real Google Play order IDs (GPA.XXXX-XXXX-XXXX-XXXXX).
 * Timestamp fallback tokens removed — forgeable by any authenticated user.
 */
function isValidPurchaseToken(token: string): boolean {
  return /^GPA\.\d{4}-\d{4}-\d{4}-\d+$/.test(token);
}

Deno.serve(async (req) => {
  // ... auth check (see Gotcha #8) ...

  // Validate token format BEFORE any DB writes
  if (!isValidPurchaseToken(purchaseToken)) {
    console.warn(`[verify-google-purchase] Invalid token: "${purchaseToken}" user=${user.id}`);
    return new Response(JSON.stringify({ error: "Invalid purchaseToken format" }), { status: 400 });
  }

  // NOTE: update_subscription_status intentionally omitted — see security note above.

  // Grant credits — idempotent via orderId.
  // p_check_recent_grant=true: 25-day guard runs INSIDE the RPC under advisory lock,
  // eliminating TOCTOU race between this function and revenuecat-webhook INITIAL_PURCHASE
  // (which uses a different reference_id format — ON CONFLICT alone won't dedup them).
  const referenceId = `gp-${purchaseToken}`;
  const { data: grantResult } = await supabase.rpc("grant_subscription_credits", {
    p_user_id: user.id,
    p_amount: tierInfo.credits,
    p_description: `${tierInfo.tier} subscription — Google Play purchase`,
    p_reference_id: referenceId,
    p_check_recent_grant: true,  // ← REQUIRED — see Gotcha #15
  });

  // grantResult: { granted: boolean, reason: string }
  // reason: "duplicate_reference_id" | "recent_grant_exists" | null (when granted=true)
  const creditsGranted = grantResult?.granted === true ? tierInfo.credits : 0;

  return new Response(JSON.stringify({
    verified: true,
    tier: tierInfo.tier,
    credits: creditsGranted,
    credits_already_granted: grantResult?.granted === false,
  }), { status: 200 });
});
```

#### 5.2 revenuecat-webhook (authoritative)
```typescript
// supabase/functions/revenuecat-webhook/index.ts
// Deploy: supabase functions deploy revenuecat-webhook --no-verify-jwt

// Guard: empty-string secret bypasses auth check if not caught
if (!REVENUECAT_WEBHOOK_SECRET) {
  return new Response(JSON.stringify({ error: "Server misconfigured" }), { status: 500 });
}

// Verify webhook auth — raw token comparison, NO Bearer prefix (see Gotcha #6)
const authHeader = req.headers.get("Authorization");
const expectedAuth = REVENUECAT_WEBHOOK_SECRET;  // ← raw token, no prefix
const encoder = new TextEncoder();
const a = encoder.encode(authHeader ?? "");
const b = encoder.encode(expectedAuth);
let diff = a.length ^ b.length;
const len = Math.min(a.length, b.length);
for (let i = 0; i < len; i++) diff |= a[i] ^ b[i];
const authValid = authHeader !== null && diff === 0;
if (!authValid) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });

const body = await req.json();
const event = body.event;

// eventId fallback chain — DO NOT use Date.now() as last resort (see Gotcha #17 note)
const eventId = event.id
  ?? event.transaction_id
  ?? `${event.app_user_id}-${event.type}-${event.event_timestamp_ms ?? "no-timestamp"}`;

switch (event.type) {
  case "INITIAL_PURCHASE": {
    await supabase.rpc("update_subscription_status", {
      p_user_id: userId, p_is_premium: true, p_tier: tierInfo.tier, p_expires_at: expiresAt,
    });
    // p_check_recent_grant=true: 25-day guard eliminates TOCTOU race with verify-google-purchase
    const { data: grantResult } = await supabase.rpc("grant_subscription_credits", {
      p_user_id: userId, p_amount: tierInfo.credits,
      p_description: `${tierInfo.tier} subscription — initial purchase`,
      p_reference_id: eventId,
      p_check_recent_grant: true,   // ← REQUIRED for INITIAL_PURCHASE (see Gotcha #15)
    });
    if (grantResult?.granted === false) { /* skip duplicate, log reason */ break; }
    break;
  }
  case "RENEWAL": {
    await supabase.rpc("update_subscription_status", { ... });
    // p_check_recent_grant=false: RENEWAL events have unique eventIds — ON CONFLICT handles dedup
    await supabase.rpc("grant_subscription_credits", {
      p_reference_id: eventId,
      p_check_recent_grant: false,  // ← RENEWAL: dedup via reference_id only
      ...
    });
    break;
  }
  case "EXPIRATION": {
    // MUST pass p_tier: "free" — passing null writes NULL (not column default)  ← Gotcha #13
    await supabase.rpc("update_subscription_status", {
      p_is_premium: false, p_tier: "free", p_expires_at: null, ...
    });
    break;
  }
  case "PRODUCT_CHANGE": {
    // Use event.new_product_id — not event.product_id (that's the old product)
    const newProductId = event.new_product_id ?? event.product_id;
    await supabase.rpc("update_subscription_status", { p_tier: getTierInfo(newProductId)?.tier, ... });
    break;
  }
  case "CANCELLATION":
    // User keeps access until expiry — just log, no DB change needed
    break;
  case "BILLING_ISSUES_DETECTED":
    console.warn(`Billing issues for ${event.app_user_id}`);
    break;
}
```

**Double-grant prevention:** `verify-google-purchase` uses `gp-{orderId}` as reference_id. RC webhook uses `event.id` (UUID). `ON CONFLICT(reference_id)` alone will NOT dedup across both — they are different strings. The `p_check_recent_grant=true` parameter runs a 25-day per-user guard INSIDE the RPC under `pg_advisory_xact_lock` (atomic, no TOCTOU race). Whichever function fires first wins; the second gets `{ granted: false, reason: "recent_grant_exists" }` and skips. See Gotcha #15 for full details.

#### 5.3 sync-subscription (status sync only — NO credits)
```typescript
// Called after purchase/restore to sync RC entitlements → Supabase
// IMPORTANT: Must NOT grant credits here — double-grant risk
// Only calls update_subscription_status, never grant_subscription_credits

// 5-minute race condition guard (see Gotcha #16):
// If RC returns 0 entitlements but profile was set premium < 5 min ago,
// skip downgrade — RC may still be processing the purchase.
if (!isPremium) {
  const isRecentlyUpdated = profile?.is_premium === true
    && profileUpdatedAt > new Date(Date.now() - 5 * 60 * 1000);
  if (isRecentlyUpdated) {
    return { synced: false, reason: "rc_processing_in_flight" };
  }
  // Otherwise trust RC as authoritative — downgrade user
  await supabase.rpc("update_subscription_status", {
    p_is_premium: false, p_tier: "free", p_expires_at: null, ...
  });
}
```

#### 5.4 Deploy all functions with --no-verify-jwt
```bash
# MUST use --no-verify-jwt for all functions called by Flutter app
supabase functions deploy verify-google-purchase --no-verify-jwt --project-ref YOUR_REF
supabase functions deploy sync-subscription      --no-verify-jwt --project-ref YOUR_REF
supabase functions deploy revenuecat-webhook     --no-verify-jwt --project-ref YOUR_REF
```

#### 5.5 Set required secrets
```bash
supabase secrets set REVENUECAT_WEBHOOK_SECRET=YOUR_SECRET --project-ref YOUR_REF
# SUPABASE_SERVICE_ROLE_KEY is auto-injected by Supabase, no need to set manually
```

---

### PHASE 6: Database Setup

#### 6.1 Required tables
```sql
-- Subscription status on user profile
ALTER TABLE profiles ADD COLUMN is_premium BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN subscription_tier TEXT;  -- 'pro', 'ultra', etc.
ALTER TABLE profiles ADD COLUMN premium_expires_at TIMESTAMPTZ;

-- Credits balance
CREATE TABLE user_credits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0)
);

-- Credit transaction log with idempotency
CREATE TABLE credit_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  amount INTEGER NOT NULL,
  description TEXT,
  reference_id TEXT,  -- idempotency key
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX credit_transactions_reference_id_idx
  ON credit_transactions(reference_id) WHERE reference_id IS NOT NULL;
```

#### 6.2 Required RPC functions

> ⚠️ `credit_transactions` needs a `type TEXT` column (used by the 25-day guard SELECT). Add to 6.1 CREATE TABLE or via migration: `ALTER TABLE credit_transactions ADD COLUMN type TEXT DEFAULT 'subscription';`

```sql
-- grant_subscription_credits: atomic, idempotent, RETURNS JSONB
-- ⚠️ DO NOT use RETURNS VOID — return shape changed to carry grant result:
--    { granted: true } | { granted: false, reason: 'duplicate_reference_id' | 'recent_grant_exists' }
DROP FUNCTION IF EXISTS grant_subscription_credits(UUID, INTEGER, TEXT, TEXT);

CREATE FUNCTION grant_subscription_credits(
  p_user_id            UUID,
  p_amount             INTEGER,
  p_description        TEXT,
  p_reference_id       TEXT,
  p_check_recent_grant BOOLEAN DEFAULT FALSE  -- set true for INITIAL_PURCHASE, false for RENEWAL
) RETURNS JSONB AS $$
DECLARE
  v_lock_key BIGINT;
BEGIN
  -- Advisory lock: serializes concurrent grant attempts for same user
  v_lock_key := hashtext(p_user_id::TEXT)::BIGINT;
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- NULL reference_id bypasses ON CONFLICT dedup — guard explicitly
  IF p_reference_id IS NULL THEN
    RAISE EXCEPTION 'grant_subscription_credits: p_reference_id must not be NULL';
  END IF;

  -- Optional 25-day guard (INITIAL_PURCHASE only — RENEWAL uses unique eventId for dedup)
  IF p_check_recent_grant THEN
    IF EXISTS (
      SELECT 1 FROM credit_transactions
      WHERE user_id = p_user_id AND type = 'subscription'
        AND created_at > now() - INTERVAL '25 days'
    ) THEN
      RETURN jsonb_build_object('granted', false, 'reason', 'recent_grant_exists');
    END IF;
  END IF;

  INSERT INTO credit_transactions (user_id, amount, type, description, reference_id)
  VALUES (p_user_id, p_amount, 'subscription', p_description, p_reference_id)
  ON CONFLICT (reference_id) WHERE reference_id IS NOT NULL DO NOTHING;

  IF FOUND THEN
    UPDATE user_credits SET balance = balance + p_amount WHERE user_id = p_user_id;
    RETURN jsonb_build_object('granted', true);
  END IF;

  RETURN jsonb_build_object('granted', false, 'reason', 'duplicate_reference_id');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Permissions: revoke from PUBLIC, grant only to service_role (edge functions)
REVOKE ALL ON FUNCTION grant_subscription_credits(UUID, INTEGER, TEXT, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION grant_subscription_credits(UUID, INTEGER, TEXT, TEXT, BOOLEAN) FROM authenticated;
GRANT EXECUTE ON FUNCTION grant_subscription_credits(UUID, INTEGER, TEXT, TEXT, BOOLEAN) TO service_role;

-- update_subscription_status: always pass p_tier = 'free' for downgrades, never null (Gotcha #13)
CREATE OR REPLACE FUNCTION update_subscription_status(
  p_user_id UUID, p_is_premium BOOLEAN, p_tier TEXT, p_expires_at TIMESTAMPTZ
) RETURNS VOID AS $$
BEGIN
  UPDATE profiles SET
    is_premium = p_is_premium,
    subscription_tier = p_tier,       -- SET writes p_tier directly — NULL writes NULL, not 'free'
    premium_expires_at = p_expires_at,
    updated_at = now()
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
```

---

### PHASE 7: Flutter SDK Integration

#### 7.1 pubspec.yaml
```yaml
dependencies:
  purchases_flutter: ^9.x.x
```

#### 7.2 Initialize (guard for non-web)
```dart
// main.dart — guard with !kIsWeb (RC doesn't support web)
if (!kIsWeb) {
  await Purchases.setLogLevel(LogLevel.debug);
  await Purchases.configure(
    PurchasesConfiguration(EnvConfig.revenuecatGoogleKey)
      ..appUserID = supabaseUser.id,  // Use auth user ID for cross-device sync
  );
}
```

#### 7.3 Purchase flow with verify-google-purchase fallback
```dart
Future<SubscriptionStatus> purchase(SubscriptionPackage package) async {
  final nativePkg = package.nativePackage as Package;
  final result = await Purchases.purchase(PurchaseParams.package(nativePkg));

  // transactionIdentifier on Android = orderId (GPA.xxx), NOT purchaseToken (Gotcha #9).
  // May be empty for free-trial subscriptions — orderId not yet assigned.
  final rawToken = result.storeTransaction.transactionIdentifier;
  final productId = package.identifier;

  if (rawToken.isNotEmpty) {
    // Non-blocking: user already charged — don't delay success UI
    unawaited(_verifyWithGooglePlay(rawToken, productId));
  } else {
    // ⚠️ Never use timestamp fallback — forgeable by any authenticated user (Gotcha #17)
    // RC webhook INITIAL_PURCHASE event will grant credits when it fires.
    Log.w('[RC] orderId empty (free trial?) — skipping verify, RC webhook handles credits');
  }

  return _mapCustomerInfo(result.customerInfo);
}

/// Non-blocking: errors logged but never thrown (don't break purchase flow)
Future<void> _verifyWithGooglePlay(String purchaseToken, String productId) async {
  try {
    final response = await Supabase.instance.client.functions.invoke(
      'verify-google-purchase',
      body: {'purchaseToken': purchaseToken, 'productId': productId},
    );
    final body = response.data as Map<String, dynamic>?;
    if (body?['verified'] == true) {
      Log.i('[RC] GP verify OK: tier=${body?['tier']}, credits=${body?['credits']}');
    } else if (body?['error'] != null) {
      Log.w('[RC] GP verify error from server: ${body?['error']}');
    } else {
      Log.w('[RC] GP verify skipped: ${body?['reason']}');
    }
  } on Object catch (e) {
    Log.w('[RC] verify-google-purchase failed (non-blocking): $e');
  }
}
```

#### 7.4 Error codes to handle
```dart
on PlatformException catch (e) {
  // RC error codes:
  // 1  = purchase cancelled by user → don't show error
  // 28 = ITEM_ALREADY_OWNED (Google Play)
  //      → don't call restorePurchases() — may fail with allowSharingPlayStoreAccount=false
  //      → call Purchases.getCustomerInfo() directly instead
  if (e.code == '1') return; // cancelled
  if (e.code == '28') return getStatus(); // already owned → fetch current state
  throw AppException.payment(message: e.message ?? 'Purchase failed', code: e.code);
}
```

#### 7.5 Sync to Supabase after purchase
```dart
// After purchase completes, sync RC entitlements → Supabase profiles table.
// Non-blocking: called via unawaited() so user sees success UI immediately.
Future<void> _syncToSupabase() async {
  try {
    final response = await supabase.functions.invoke('sync-subscription');
    final body = response.data as Map<String, dynamic>?;
    if (body?['synced'] == false) {
      Log.w('[Subscription] sync skipped: ${body?['reason']} — ${body?['message']}');
    } else {
      Log.i('[Subscription] sync OK: tier=${body?['tier']}, is_premium=${body?['is_premium']}');
    }
  } on Object catch (e) {
    Log.w('[Subscription] sync-subscription failed (non-blocking): $e');
  } finally {
    // ⚠️ Always invalidate in finally — refresh must happen even if sync call fails.
    // Without finally, a network error swallows the refresh and UI stays stale.
    ref
      ..invalidate(authViewModelProvider)
      ..invalidate(creditBalanceNotifierProvider);
  }
}
```

---

### PHASE 8: Webhook Setup

#### 8.1 RevenueCat Webhook Config
```
RevenueCat → Integrations → Webhooks → + New webhook
  Name: Supabase Webhook
  URL: https://YOUR_PROJECT.supabase.co/functions/v1/revenuecat-webhook
  Authorization header: YOUR_SECRET_VALUE
  Environment: Production and Sandbox  ← BOTH! Sandbox for testing
  Events: Initial purchase ✅, Renewal ✅, Product change ✅, Cancellation ✅, Expiration ✅
```

#### 8.2 Verify webhook is receiving
```
RC Dashboard → Customers → [find a test user] → check Events tab
If no events → webhook pipeline not working → debug Pub/Sub first
```

---

## ✅ Pre-check Checklist (Full)

### Google Play Console
- [ ] App created with correct package name (permanent!)
- [ ] Release-signed AAB uploaded (NOT debug-signed)
- [ ] Subscription products created and **Active** status
- [ ] Base plan configured with pricing
- [ ] Internal testing track has tester emails
- [ ] License testing: tester Gmail added in Settings → License testing
- [ ] Service account invited via Users & Permissions with correct permissions
- [ ] Real-time developer notifications topic name set

### Google Cloud Console
- [ ] Project created (personal @gmail.com recommended)
- [ ] Google Play Android Developer API enabled
- [ ] Cloud Pub/Sub API enabled ← often missed!
- [ ] Service account created with Pub/Sub Admin role
- [ ] JSON key downloaded and stored safely (NOT in git)

### RevenueCat Dashboard
- [ ] App created with correct package name
- [ ] Service account JSON uploaded → credentials valid
- [ ] RTDN topic connected → status "Connected to Google ✅"
- [ ] Send test notification → RC notification counter increases ← verify this!
- [ ] Products match Google Play IDs exactly
- [ ] Entitlements configured
- [ ] Offerings configured → one marked as **Current** (or `getOfferings().current` returns null)
- [ ] Public API key (`goog_xxx`) added to app `.env`
- [ ] Webhook configured: correct URL + secret + **Sandbox AND Production**

### Supabase Edge Functions
- [ ] All functions deployed with `--no-verify-jwt` ← critical!
- [ ] `REVENUECAT_WEBHOOK_SECRET` set in secrets
- [ ] `REVENUECAT_PROJECT_ID` set in secrets (required by sync-subscription) ← easy to miss!
- [ ] `verify-google-purchase`: GPA format validation — no timestamp fallback tokens
- [ ] `verify-google-purchase`: does NOT call `update_subscription_status` (tier escalation risk)
- [ ] `verify-google-purchase`: passes `p_check_recent_grant: true` to grant_subscription_credits
- [ ] `sync-subscription`: does NOT grant credits (only status sync)
- [ ] `sync-subscription`: has 5-minute race guard before downgrading (Gotcha #16)
- [ ] `revenuecat-webhook`: auth comparison uses raw token — no `Bearer ` prefix
- [ ] `revenuecat-webhook`: empty-string secret guard at top of handler
- [ ] `revenuecat-webhook`: uses XOR constant-time auth (NOT `crypto.subtle.timingSafeEqual`)
- [ ] `revenuecat-webhook`: INITIAL_PURCHASE passes `p_check_recent_grant: true`
- [ ] `revenuecat-webhook`: RENEWAL passes `p_check_recent_grant: false`
- [ ] `revenuecat-webhook`: eventId fallback chain: `event.id ?? event.transaction_id ?? composite`
- [ ] `revenuecat-webhook`: PRODUCT_CHANGE uses `event.new_product_id`
- [ ] EXPIRATION + PRODUCT_CHANGE handlers pass `p_tier: "free"` (NOT null)
- [ ] No top-level `throw` outside `Deno.serve()` handler (causes BOOT_ERROR)

### Database
- [ ] `profiles.is_premium`, `subscription_tier`, `premium_expires_at` columns exist
- [ ] `user_credits` table exists with balance check constraint
- [ ] `credit_transactions` has UNIQUE INDEX on reference_id
- [ ] `grant_subscription_credits` RPC uses advisory lock + ON CONFLICT
- [ ] `update_subscription_status` RPC exists and tested

### Flutter App
- [ ] `purchases_flutter` initialized only on `!kIsWeb`
- [ ] `appUserID` set to Supabase user ID
- [ ] `REVENUECAT_GOOGLE_KEY` = real `goog_xxx` key
- [ ] Purchase flow calls `verify-google-purchase` only when orderId (GPA.xxx) is non-empty
- [ ] Empty orderId → skip verify entirely (RC webhook handles credits) — no timestamp fallback
- [ ] RC error code 1 (cancelled) handled silently
- [ ] RC error code 28 (already owned) handled via `getCustomerInfo()`
- [ ] `_createUserProfile()` called BEFORE `_revenuecatLogIn()` during signUp ← race condition!
- [ ] `revenuecat_app_user_id` included in profile INSERT (not just relying on UPDATE)
- [ ] After purchase: invalidate BOTH `authViewModelProvider` AND `creditBalanceNotifierProvider`
- [ ] `.env` files NOT committed to git
- [ ] Version code bumped before each new Play Store upload
- [ ] AAB rebuilt after any `.env` change

---

## 🐛 Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `{"code":401,"message":"Invalid JWT"}` from edge fn | **ES256/HS256 mismatch** — deployed without `--no-verify-jwt` | Redeploy ALL functions with `--no-verify-jwt` |
| Credits not granted after purchase | verify-google-purchase getting 401 silently | Check function was deployed `--no-verify-jwt` |
| `is_premium` not updating | sync-subscription getting 401 silently | Same — redeploy with `--no-verify-jwt` |
| RC Dashboard: 0 Active Subscribers | RC server not receiving purchases | Check Pub/Sub → RTDN pipeline. Send test notification, verify counter increases |
| RC webhook never fires | Pub/Sub not configured correctly | Full RTDN setup: Cloud Pub/Sub API + topic + grant Pub/Sub Admin to service account |
| "Credentials need attention" on RevenueCat | Service account not yet active | Wait up to 24h after inviting |
| "Could not check" on products | Same as above | Wait 24h |
| `getOfferings().current` returns null | No offering marked as "Current" | RC Dashboard → Offerings → select default → mark as Current |
| `ITEM_ALREADY_OWNED` (error 28) | User already subscribed | Call `Purchases.getCustomerInfo()` directly (not `restorePurchases()`) |
| Double-grant when RC webhook activates | `gp-` and RC event.id are different reference_ids | Remove `grant_subscription_credits` from `verify-google-purchase` when webhook confirmed stable |
| All webhook events return 500 immediately | `crypto.subtle.timingSafeEqual` not in Supabase runtime → throws on auth check | Replace with manual XOR loop (Gotcha #11) |
| RC webhook "User not linked" 500 on new signups | `revenuecat_app_user_id` = NULL because RC login ran before profile INSERT | Fix order: INSERT profile → then `_revenuecatLogIn()`. Include field in INSERT (Gotcha #12) |
| UI credits not updating after purchase | Only `authViewModelProvider` invalidated, `creditBalanceNotifierProvider` not refreshed | Invalidate both providers in `purchase()`, `restore()`, and `_syncToSupabase()` |
| All edge function calls return 503 BOOT_ERROR | Top-level `throw` at module init → function won't start | Move env var validation inside `Deno.serve()` handler (Gotcha #14). Set `REVENUECAT_PROJECT_ID` secret |
| subscription_tier written as NULL after EXPIRATION | `p_tier: null` passed to `update_subscription_status` → UPDATE sets column to NULL | Always pass `p_tier: "free"` for downgrade/expiry events (Gotcha #13) |
| "Service account key creation is disabled" | Org policy on Google Workspace | Use personal @gmail.com for GCloud project |
| AAB rejected "signed in debug mode" | Wrong keystore used | Configure release signing in `build.gradle.kts` |
| Purchase fails in testing | Test account not in License testing | Add Gmail to Settings → License testing in Play Console |
| Webhook not receiving RC events | "Production only" in RC → misses sandbox | Change to "Production and Sandbox" in RC webhook settings |
| Empty `transactionIdentifier` | Free trial subscription, orderId not assigned yet | Skip verify call entirely — RC webhook INITIAL_PURCHASE handles credits. Never use timestamp fallback (security: forgeable). See Gotcha #17 |
| User downgraded immediately after purchase | sync-subscription races against Pub/Sub latency | Add 5-minute guard in sync-subscription: skip downgrade if profile updated < 5 min ago (Gotcha #16) |
| Double credit grant on purchase | verify-google-purchase + RC webhook both fire — different reference_ids bypass ON CONFLICT | Use `p_check_recent_grant: true` in INITIAL_PURCHASE handlers (Gotcha #15) |

---

## 🔒 Security Checklist

- [ ] `purchaseToken` validated against GPA format regex only (`^GPA\.\d{4}-\d{4}-\d{4}-\d+$`) — no timestamp fallbacks
- [ ] `verify-google-purchase` does NOT call `update_subscription_status` (prevents client-side tier escalation)
- [ ] `p_check_recent_grant: true` passed for INITIAL_PURCHASE in both verify-google-purchase and revenuecat-webhook
- [ ] `p_check_recent_grant: false` passed for RENEWAL (dedup via reference_id only)
- [ ] Webhook secret compared as raw token — no `Bearer ` prefix construction
- [ ] Edge functions use `--no-verify-jwt` + manual `auth.getUser()` (not skipping auth entirely)
- [ ] Webhook verified with timing-safe XOR loop (NOT `crypto.subtle.timingSafeEqual` — not available in Supabase runtime)
- [ ] Empty-string secret guard at top of webhook handler (before any auth logic)
- [ ] sync-subscription has 5-minute race guard before downgrading user
- [ ] Service account JSON key NOT committed to git (add `*.json` + `service-account*.json` to `.gitignore`)
- [ ] Keystore files NOT committed to git (add `*.jks`, `*.keystore`, `keystore.properties` to `.gitignore`)
- [ ] `REVENUECAT_WEBHOOK_SECRET` only in Supabase secrets, not in code

---

## 📁 File Structure Reference

```
android/app/
  build.gradle.kts          ← applicationId, signingConfigs, keystoreProps
  *.jks                     ← Release keystore (DO NOT COMMIT)
  keystore.properties       ← Keystore credentials (DO NOT COMMIT)

lib/features/subscription/
  data/repositories/
    subscription_repository.dart  ← RC SDK calls, verify-google-purchase call
  domain/
    entities/subscription_status.dart
    repositories/i_subscription_repository.dart
  presentation/
    providers/subscription_provider.dart  ← purchase(), restore(), _syncToSupabase()

.env.development                 ← Dev secrets (git-ignored)
.env.production                  ← Prod secrets (git-ignored)

supabase/functions/
  verify-google-purchase/index.ts  ← Immediate credit grant ONLY — no tier update (client-side productId untrusted)
  sync-subscription/index.ts       ← RC entitlement sync, NO credit grants
  revenuecat-webhook/index.ts      ← Authoritative: full lifecycle events

supabase/migrations/
  *_add_subscription_support.sql   ← profiles columns, user_credits, credit_transactions
  *_fix_credit_idempotency.sql     ← UNIQUE INDEX on reference_id, RPC functions
```

---

## 📈 Verification After Setup

Run these queries to confirm end-to-end after a real purchase:

```sql
-- 1. Check profiles updated correctly
SELECT id, is_premium, subscription_tier, premium_expires_at, updated_at
FROM profiles WHERE is_premium = true ORDER BY updated_at DESC LIMIT 10;

-- 2. Check credits granted with correct reference_id format
SELECT user_id, amount, reference_id, description, created_at
FROM credit_transactions
WHERE description LIKE '%subscription%'
ORDER BY created_at DESC LIMIT 10;
-- Expected: reference_id = 'gp-GPA.xxxx-xxxx-xxxx-xxxxx' (from verify-google-purchase)
-- Or: reference_id = UUID (from RC webhook — if webhook is working)

-- 3. Check user_credits balance
SELECT user_id, balance FROM user_credits
WHERE user_id IN (SELECT id FROM profiles WHERE is_premium = true)
ORDER BY balance DESC;
```

**Healthy state indicators:**
- `is_premium = true`, `subscription_tier` set ✅
- `credit_transactions` has `gp-GPA.xxx` entry with correct amount ✅
- `user_credits.balance` = welcome_bonus + subscription_credits - usage ✅
- RC Dashboard → Customers → user appears with active subscription ✅ *(only after RC webhook works)*
