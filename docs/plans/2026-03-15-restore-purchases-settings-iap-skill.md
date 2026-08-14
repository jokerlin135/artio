# Restore Purchases in Settings + IAP Skill Update Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add "Restore Purchases" tile to Settings Account section (Apple requirement) and update IAP skill with 3 new production-verified gotchas discovered 2026-03-15.

**Architecture:** `SettingsSections` is already a `ConsumerWidget` — restore is handled internally via `subscriptionNotifierProvider` (same pattern as `PaywallScreen._handleRestore`). No new callback needed. Skill update is a doc-only change.

**Tech Stack:** Flutter, Riverpod, `purchases_flutter`, `.agent/skills/iap-revenuecat/SKILL.md`

---

### Task 1: Create feature branch

**Step 1: Switch to main and create branch**

```bash
git checkout main && git pull origin main
git checkout -b feat/restore-purchases-settings
```

Expected: on branch `feat/restore-purchases-settings`

---

### Task 2: Add "Restore Purchases" tile to SettingsSections

**Files:**
- Modify: `lib/features/settings/presentation/widgets/settings_sections.dart`

**Context:**
- `SettingsSections` is a `ConsumerWidget` — can call `ref.read(subscriptionNotifierProvider.notifier).restore()` directly
- Insert tile after "Manage Plan / Upgrade Plan" block (after the `isPremium ? ...` onTap block), before "Credit History" divider
- Only show when `isLoggedIn && !kIsWeb`
- Show SnackBar on success/failure (same pattern as `PaywallScreen._handleRestore`)

**Step 1: Add `_handleRestore` method + `_isRestoring` state**

`SettingsSections` is currently stateless. Convert to `ConsumerStatefulWidget` to track loading state OR use a simpler approach: add an `onRestore` callback that handles state in `SettingsScreen`.

**Simpler approach (no StatefulWidget):** Add `required VoidCallback onRestore` param — caller owns state. SettingsScreen already uses `ref` so can call the notifier.

**Modify `lib/features/settings/presentation/widgets/settings_sections.dart`:**

Add param to constructor (after `onSignOut`):
```dart
required this.onRestore,
```

Add field:
```dart
final VoidCallback onRestore;
```

Add tile inside the `if (isLoggedIn)` Account block, after the Manage/Upgrade Plan tile divider, before Credit History:

```dart
SettingsDivider(isDark: isDark),
SettingsTile(
  icon: Icons.restore_rounded,
  iconBgColor: AppColors.info,
  title: 'Restore Purchases',
  trailing: SettingsChevronArrow(isDark: isDark),
  isDark: isDark,
  onTap: kIsWeb ? null : onRestore,
),
```

**Step 2: Wire up in `lib/features/settings/presentation/settings_screen.dart`**

Add restore handler method to `_SettingsScreenState`:
```dart
Future<void> _restorePurchases(BuildContext context) async {
  try {
    await ref.read(subscriptionNotifierProvider.notifier).restore();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Purchases restored!')),
      );
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore failed. Please try again.')),
      );
    }
  }
}
```

Wire into `SettingsSections` call:
```dart
SettingsSections(
  email: email,
  isDark: isDark,
  version: _version,
  isLoggedIn: isLoggedIn,
  isPremium: isPremium,
  onResetPassword: () => _resetPassword(context, email),
  onSignOut: () => _signOut(context),
  onRestore: () => _restorePurchases(context),
),
```

**Step 3: Run analyze**
```bash
flutter analyze
```
Expected: No issues found.

---

### Task 3: Add tests for Restore Purchases tile

**Files:**
- Modify: `test/features/settings/presentation/widgets/settings_sections_test.dart`

**Step 1: Add `onRestore` to `buildWidget` helper**

In `buildWidget`, add `onRestore: () {}` to `SettingsSections`:
```dart
onRestore: () {},
```

**Step 2: Write failing tests**

Add to the `group('SettingsSections')` block:

```dart
testWidgets('shows Restore Purchases tile when logged in', (tester) async {
  await tester.pumpWidget(buildWidget());
  await tester.pumpAndSettle();

  expect(find.text('Restore Purchases'), findsOneWidget);
});

testWidgets('hides Restore Purchases tile when not logged in', (tester) async {
  await tester.pumpWidget(buildWidget(isLoggedIn: false));
  await tester.pumpAndSettle();

  expect(find.text('Restore Purchases'), findsNothing);
});

testWidgets('calls onRestore when Restore Purchases tile tapped', (tester) async {
  var called = false;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsSections(
              email: 'test@example.com',
              isDark: false,
              version: '1.0.0',
              isLoggedIn: true,
              isPremium: false,
              onResetPassword: () {},
              onSignOut: () {},
              onRestore: () { called = true; },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Restore Purchases'));
  expect(called, isTrue);
});
```

**Step 3: Run tests to verify they fail first**
```bash
flutter test test/features/settings/presentation/widgets/settings_sections_test.dart -v
```
Expected: 3 new tests FAIL (Restore Purchases tile not yet added).

**Step 4: Implement (Task 2 above) then run tests again**
```bash
flutter test test/features/settings/presentation/widgets/settings_sections_test.dart -v
```
Expected: All tests PASS.

**Step 5: Run full test suite**
```bash
flutter test
```
Expected: All tests pass.

**Step 6: Commit**
```bash
git add lib/features/settings/presentation/widgets/settings_sections.dart \
        lib/features/settings/presentation/settings_screen.dart \
        test/features/settings/presentation/widgets/settings_sections_test.dart
git commit -m "feat(settings): add Restore Purchases tile to Account section

Apple App Store requires Restore Purchases to be easily accessible
(not just on the paywall). Tile is shown in Settings > Account when
logged in and on mobile (hidden on web where RevenueCat is not init).
Calls subscriptionNotifierProvider.restore() via onRestore callback."
```

---

### Task 4: Update IAP skill with 3 new production gotchas

**Files:**
- Modify: `.agent/skills/iap-revenuecat/SKILL.md`

**Step 1: Find and fix Gotcha #11 (timingSafeEqual)**

Find the section that says "`crypto.subtle.timingSafeEqual` NOT available in Supabase Edge Runtime". This is **incorrect** — it IS available in Deno/Supabase via type cast.

Replace the warning with the correct info:

```markdown
### 11. 🔄 UPDATED: `crypto.subtle.timingSafeEqual` IS Available in Deno (Type Cast Required)

**Previous warning was wrong.** `crypto.subtle.timingSafeEqual` IS available in Supabase Edge Runtime
(Deno-based) but the TypeScript type definitions don't include it. Use a type cast:

```typescript
const authValid = (
  crypto.subtle as unknown as {
    timingSafeEqual(a: BufferSource, b: BufferSource): boolean;
  }
).timingSafeEqual(encoder.encode(authHeader), encoder.encode(expected));
```

This works correctly in production. The manual XOR approach also works but is unnecessary.
```

**Step 2: Add new Gotcha #12 — Migration must be applied to prod explicitly**

After Gotcha #11, add:

```markdown
### 12. 🆕 Supabase Migrations Do NOT Auto-Deploy to Production

**Problem:** Running `supabase db push` locally or merging a PR does NOT automatically apply
migrations to the remote Supabase project. The migration exists in `supabase/migrations/` but
the production DB function signature stays old.

**Symptom:** Edge function calls RPC with new parameters → PostgREST returns
`"Could not find the function public.X with parameters..."` → function returns 500 → RC retries.

**Fix:** After any migration, explicitly apply to production:
```bash
SUPABASE_ACCESS_TOKEN=<token>
# Option A: via Management API (no Docker needed)
curl -s -X POST "https://api.supabase.com/v1/projects/<ref>/database/query" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"<migration SQL here>\"}"

# Option B: via CLI (requires Docker)
supabase db push --project-ref <ref>
```

**Always verify** after applying:
```bash
curl -s "https://<ref>.supabase.co/rest/v1/rpc/grant_subscription_credits" \
  -X POST -H "apikey: <service_role_key>" \
  -d '{"p_user_id":"...","p_amount":1,"p_description":"test","p_reference_id":"test","p_check_recent_grant":false}'
# Expected: FK error (not "function not found") = signature correct
```
```

**Step 3: Add new Gotcha #13 — RC Webhook retrying = check migration applied**

```markdown
### 13. 🆕 RC Webhook "Retrying" Loop — Check Migration Applied to Production

**Symptom:** RevenueCat dashboard shows webhook events stuck in "Retrying" status.
Supabase Edge Function logs show 500 responses.

**Root cause pattern:** Edge function code was updated to call RPC with new parameters
(e.g. `p_check_recent_grant`), but the migration that adds those parameters was never
applied to the production DB → RPC call fails → 500 → RC retries every few minutes.

**Debug checklist:**
1. RC Dashboard → Integrations → Webhooks → expand a failing event → check response body
2. If response is `"Could not find the function public.X with parameters..."` → migration not applied
3. Apply migration (see Gotcha #12)
4. Redeploy the edge function: `supabase functions deploy revenuecat-webhook --no-verify-jwt --project-ref <ref>`
5. RC Dashboard → click "Retry" on failing events → confirm they now succeed (no new "Retrying")

**Note:** RC Pub/Sub pipeline being connected (transactions visible in RC dashboard) does NOT
mean webhooks work — the pipeline can be connected but webhooks still fail if the edge function returns 5xx.
```

**Step 4: Update pre-check checklist in skill**

Find the pre-check checklist section and add:
```markdown
- [ ] All migrations applied to production DB (not just in `supabase/migrations/` folder)
- [ ] RC webhook events in RC Dashboard → NOT stuck in "Retrying" status
- [ ] Restore Purchases accessible in Settings (not just Paywall) — required for Apple App Store
```

**Step 5: Run analyze (no Dart changes, just docs)**
```bash
flutter analyze
```
Expected: No issues found.

**Step 6: Commit**
```bash
git add .agent/skills/iap-revenuecat/SKILL.md
git commit -m "docs(skill): update iap-revenuecat skill with 3 production gotchas

Gotcha #11: timingSafeEqual IS available in Deno with type cast (prev warning was wrong)
Gotcha #12: Supabase migrations must be explicitly applied to prod DB
Gotcha #13: RC webhook Retrying loop = migration not applied to prod (not Pub/Sub issue)
Pre-check: add migration prod check + RC webhook status + Restore in Settings"
```

---

### Task 5: Push + create PR

**Step 1: Push branch**
```bash
export GITHUB_TOKEN=$(grep GITHUB_TOKEN .env.development | cut -d= -f2)
git push origin feat/restore-purchases-settings
```

**Step 2: Create PR**
```bash
gh pr create \
  --title "feat(settings): add Restore Purchases tile + update IAP skill gotchas" \
  --body "## Summary
- Add 'Restore Purchases' tile in Settings → Account section (Apple App Store requirement)
- Update IAP skill with 3 new production-verified gotchas (timingSafeEqual, migration prod deploy, webhook retry root cause)

## Changes
- \`settings_sections.dart\`: new \`onRestore\` callback + tile after Manage/Upgrade Plan
- \`settings_screen.dart\`: \`_restorePurchases()\` handler with SnackBar feedback
- \`settings_sections_test.dart\`: 3 new tests (show, hide when not logged in, tap callback)
- \`.agent/skills/iap-revenuecat/SKILL.md\`: Gotcha #11 corrected + #12 + #13 added

## Test plan
- [ ] flutter analyze — 0 issues
- [ ] flutter test — all pass
- [ ] Settings → logged in → Restore Purchases tile visible
- [ ] Settings → not logged in → tile hidden
- [ ] Tap Restore → success SnackBar shows" \
  --base main
```

---
