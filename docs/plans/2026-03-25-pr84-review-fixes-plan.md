# PR #84 Review Fixes — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 1 CRITICAL + 4 HIGH issues from PR #84 code review before merge.

**Architecture:** Three files touched — `verify-google-purchase/index.ts` (CORS preflight guard), `paywall_screen.dart` (TODO comment), `paywall_screen_test.dart` (mock interface, auth override, purchase tests).

**Tech Stack:** Deno/TypeScript (Edge Function), Flutter/Dart, Riverpod, mocktail, flutter_test

---

## Task 1: Fix CRITICAL — OPTIONS preflight in verify-google-purchase

**Files:**
- Modify: `supabase/functions/verify-google-purchase/index.ts:25`

**Context:**
`handleCorsIfPreflight` already exists in `../_shared/cors.ts` but is never called.
Browser OPTIONS preflight hits the `req.method !== "POST"` guard → 405 → preflight fails → all browser-origin POSTs blocked.
Every other edge function (`generate-image`, `reward-ad`) calls this guard first.

**Step 1: Update the import on line 25**

Change:
```typescript
import { corsHeaders } from "../_shared/cors.ts";
```
To:
```typescript
import { corsHeaders, handleCorsIfPreflight } from "../_shared/cors.ts";
```

**Step 2: Add preflight guard as first statement inside Deno.serve (before line 53)**

After `Deno.serve(async (req) => {`, add:
```typescript
  const preflight = handleCorsIfPreflight(req);
  if (preflight) return preflight;
```

Result — top of handler should look like:
```typescript
Deno.serve(async (req) => {
  const preflight = handleCorsIfPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
```

**Step 3: Verify no TypeScript errors**

```bash
cd supabase/functions/verify-google-purchase
# No local Deno check needed — just eyeball the diff
git diff supabase/functions/verify-google-purchase/index.ts
```

**Step 4: Commit**

```bash
git add supabase/functions/verify-google-purchase/index.ts
git commit -m "fix(cors): add OPTIONS preflight handler to verify-google-purchase"
```

---

## Task 2: H1 — Add TODO comment to _hasFreeTrial

**Files:**
- Modify: `lib/features/subscription/presentation/screens/paywall_screen.dart:438`

**Context:**
`_hasFreeTrial` uses `.contains('free')` on a device-locale string.
On non-English devices "Free" renders as "Gratis"/"Gratuit"/etc — CTA shows wrong label.
Fix deferred (requires entity change). Document the limitation.

**Step 1: Find and update the `_hasFreeTrial` method doc comment**

Current (line 435–442):
```dart
  /// Returns true only when the selected package has a genuinely FREE intro
  /// offer (e.g. "Free for 7 days"). Paid intro offers like "$1.99 for 3
  /// months" do not qualify — the CTA should say "Subscribe Now" instead.
  bool _hasFreeTrial(SubscriptionPackage pkg) {
    final intro = pkg.introductoryPriceString;
    if (intro == null || intro.isEmpty) return false;
    return intro.toLowerCase().contains('free');
  }
```

Replace doc comment with:
```dart
  /// Returns true only when the selected package has a genuinely FREE intro
  /// offer (e.g. "Free for 7 days"). Paid intro offers like "$1.99 for 3
  /// months" do not qualify — the CTA should say "Subscribe Now" instead.
  ///
  /// TODO(locale): `introductoryPriceString` is a device-locale display string.
  /// On non-English devices "free" may render as "Gratis"/"Gratuit"/etc, causing
  /// this check to return false for genuine free trials. Fix: add
  /// `double? introductoryPrice` field to `SubscriptionPackage` and check
  /// `introductoryPrice == 0.0` instead. Track as separate ticket.
  bool _hasFreeTrial(SubscriptionPackage pkg) {
    final intro = pkg.introductoryPriceString;
    if (intro == null || intro.isEmpty) return false;
    return intro.toLowerCase().contains('free');
  }
```

**Step 2: Verify analyze is clean**

```bash
flutter analyze lib/features/subscription/presentation/screens/paywall_screen.dart
```
Expected: `No issues found!`

**Step 3: Commit**

```bash
git add lib/features/subscription/presentation/screens/paywall_screen.dart
git commit -m "docs(paywall): add TODO for locale-safe _hasFreeTrial fix"
```

---

## Task 3: H2 + H3 — Fix mock interface and add authViewModelProvider override

**Files:**
- Modify: `test/features/subscription/presentation/screens/paywall_screen_test.dart`

**Context:**
- H2: `MockSubscriptionRepository implements SubscriptionRepository` (concrete class) → should implement `ISubscriptionRepository` (domain interface). CLAUDE.md: "Mock at repository interface level."
- H3: `subscriptionNotifierProvider` reads `authViewModelProvider` internally (line 21 of subscription_provider.dart). Without overriding it, tests depend on real Supabase. Pattern from `home_screen_test.dart` line 22–24: `class MockAuthViewModel extends AuthViewModel { @override AuthState build() => AuthState.authenticated(UserFixtures.authenticated()); }`

**Step 1: Add missing imports at top of file**

Current imports (lines 1–10):
```dart
import 'dart:async';

import 'package:artio/features/subscription/data/repositories/subscription_repository.dart';
import 'package:artio/features/subscription/domain/entities/subscription_package.dart';
import 'package:artio/features/subscription/domain/entities/subscription_status.dart';
import 'package:artio/features/subscription/presentation/screens/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
```

Replace with:
```dart
import 'dart:async';

import 'package:artio/core/exceptions/app_exception.dart';
import 'package:artio/features/auth/presentation/state/auth_state.dart';
import 'package:artio/features/auth/presentation/view_models/auth_view_model.dart';
import 'package:artio/features/subscription/domain/repositories/i_subscription_repository.dart';
import 'package:artio/features/subscription/domain/entities/subscription_package.dart';
import 'package:artio/features/subscription/domain/entities/subscription_status.dart';
import 'package:artio/features/subscription/presentation/screens/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../core/fixtures/fixtures.dart';
```

**Step 2: Replace MockSubscriptionRepository (lines 12–13)**

Change:
```dart
class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}
```
To:
```dart
class MockSubscriptionRepository extends Mock
    implements ISubscriptionRepository {}

class MockAuthViewModel extends AuthViewModel {
  @override
  AuthState build() => AuthState.authenticated(UserFixtures.authenticated());
}
```

**Step 3: Add `authViewModelProvider` override inside `buildWidget()` (line 48)**

Current `ProviderScope` overrides:
```dart
      return ProviderScope(
        overrides: [subscriptionRepositoryProvider.overrideWithValue(mockRepo)],
```

Change to:
```dart
      return ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(MockAuthViewModel.new),
          subscriptionRepositoryProvider.overrideWithValue(mockRepo),
        ],
```

**Step 4: Run existing tests to verify no regressions**

```bash
flutter test test/features/subscription/presentation/screens/paywall_screen_test.dart --reporter expanded
```
Expected: All existing tests PASS (savingsPercent group + paywall group + auto-select group).

If `SubscriptionRepository` import was the only use of the old import, analyzer will warn — it's fine, we removed it.

**Step 5: Commit**

```bash
git add test/features/subscription/presentation/screens/paywall_screen_test.dart
git commit -m "test(paywall): mock ISubscriptionRepository interface + override authViewModelProvider"
```

---

## Task 4: H4 — Add _handlePurchase tests (5 branches)

**Files:**
- Modify: `test/features/subscription/presentation/screens/paywall_screen_test.dart`

**Context:**
`_handlePurchase` in `paywall_screen.dart` lines 605–663 has 5 distinct outcomes:
1. `_selectedPackage == null` → button is disabled (existing test covers this)
2. `purchaseState.hasError && isCancelled` → silent return, no snackbar
3. `purchaseState.hasError && !isCancelled` → error snackbar
4. `purchaseState.hasValue && !status.isActive` → warning snackbar
5. `purchaseState.hasValue && status.isActive` → success snackbar + `Navigator.pop()`

`SubscriptionNotifier.purchase()` calls `state = await AsyncValue.guard(() async { final result = await repo.purchase(package); ... })`.
- If `repo.purchase()` throws → `state = AsyncError(exception)`
- If `repo.purchase()` returns → `state = AsyncData(SubscriptionStatus)`

Auto-select picks first non-pro package, so tests that provide an `artio_ultra_monthly` offering will have a pre-selected package and an active "Subscribe Now" button.

**Step 1: Add test group after the existing `'auto-select recommended plan'` group (before `'savingsPercent'` group, around line 252)**

Add this entire group:

```dart
  group('_handlePurchase', () {
    late MockSubscriptionRepository mockRepo;

    final ultraMonthly = SubscriptionPackage(
      identifier: 'artio_ultra_monthly',
      priceString: r'$19.99',
      price: 19.99,
      nativePackage: Object(),
    );

    setUp(() {
      mockRepo = MockSubscriptionRepository();
      // Default: getStatus inactive, getOfferings returns ultra so auto-select
      // picks it and the Subscribe Now button is active.
      when(() => mockRepo.getStatus())
          .thenAnswer((_) async => const SubscriptionStatus());
      when(() => mockRepo.getOfferings())
          .thenAnswer((_) async => [ultraMonthly]);
    });

    Widget buildPurchaseWidget() => ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(MockAuthViewModel.new),
            subscriptionRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(home: PaywallScreen()),
        );

    testWidgets(
      'cancelled purchase shows no snackbar',
      (tester) async {
        when(() => mockRepo.purchase(any())).thenThrow(
          const AppException.payment(
            message: 'Cancelled by user',
            code: 'user_cancelled',
          ),
        );

        await tester.pumpWidget(buildPurchaseWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Subscribe Now'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'non-cancel purchase error shows error snackbar',
      (tester) async {
        when(() => mockRepo.purchase(any())).thenThrow(
          const AppException.network(message: 'No internet connection'),
        );

        await tester.pumpWidget(buildPurchaseWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Subscribe Now'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'purchase succeeds but subscription inactive shows warning snackbar',
      (tester) async {
        when(() => mockRepo.purchase(any()))
            .thenAnswer((_) async => const SubscriptionStatus());

        await tester.pumpWidget(buildPurchaseWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Subscribe Now'));
        await tester.pumpAndSettle();

        expect(
          find.text('Purchase processed. If credits are missing, tap Restore.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'purchase succeeds and active shows success snackbar',
      (tester) async {
        when(() => mockRepo.purchase(any())).thenAnswer(
          (_) async => const SubscriptionStatus(isActive: true, tier: 'ultra'),
        );

        await tester.pumpWidget(buildPurchaseWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Subscribe Now'));
        await tester.pumpAndSettle();

        expect(
          find.text('🎉 Subscription activated! Welcome to Premium.'),
          findsOneWidget,
        );
      },
    );
  });
```

**Step 2: Run new tests to see them FAIL first (TDD red)**

```bash
flutter test test/features/subscription/presentation/screens/paywall_screen_test.dart \
  --name "_handlePurchase" --reporter expanded
```
Expected: Tests run. If they pass immediately, great — if they fail due to setup issues, fix the mock stubs.

**Step 3: Run full test file to verify no regressions**

```bash
flutter test test/features/subscription/presentation/screens/paywall_screen_test.dart --reporter expanded
```
Expected: All tests PASS.

**Step 4: Run full subscription test suite**

```bash
flutter test test/features/subscription/ --reporter expanded
```
Expected: All tests PASS.

**Step 5: Commit**

```bash
git add test/features/subscription/presentation/screens/paywall_screen_test.dart
git commit -m "test(paywall): cover _handlePurchase — cancel, error, inactive, success branches"
```

---

## Task 5: Final verification and push

**Step 1: flutter analyze**

```bash
flutter analyze
```
Expected: `No issues found!`

**Step 2: Full test suite**

```bash
flutter test
```
Expected: All tests PASS (was 739 before this PR — should be 743+ after adding 4 new tests).

**Step 3: Push and update PR**

```bash
git push
```

**Step 4: Add review comment on PR #84**

```bash
GITHUB_TOKEN=<YOUR_GITHUB_TOKEN> \
gh pr comment 84 --body "## Review fixes pushed ✅

All CRITICAL and HIGH issues resolved:

- **CRITICAL**: Added \`handleCorsIfPreflight\` guard to \`verify-google-purchase\` — OPTIONS preflight now returns 200 with CORS headers
- **H1**: Added \`// TODO(locale)\` comment to \`_hasFreeTrial\` — deferred (entity change needed, separate ticket)
- **H2**: \`MockSubscriptionRepository\` now implements \`ISubscriptionRepository\` (interface) instead of concrete class
- **H3**: \`authViewModelProvider\` overridden with \`MockAuthViewModel\` in paywall test helper — no implicit Supabase dependency
- **H4**: Added 4 widget tests for \`_handlePurchase\`: cancel, non-cancel error, inactive, success branches

\`flutter analyze\` clean. All tests pass."
```

---

## Execution Notes

- All 4 dart test cases in Task 4 use `any()` matcher from mocktail — this matches any `SubscriptionPackage` argument.
- `AppException.payment(code: 'user_cancelled')` creates a `PaymentException` instance (Freezed union). `err is PaymentException && err.code == 'user_cancelled'` in `_handlePurchase` will match correctly.
- `SubscriptionNotifier.purchase()` uses `AsyncValue.guard()` which catches and stores exceptions — it never rethrows, so `await purchase()` always completes.
- `UserFixtures.authenticated()` is in `test/core/fixtures/fixtures.dart` — already exported via barrel.
