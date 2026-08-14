# PR #84 Review Fixes — Design Doc

**Date:** 2026-03-25
**Branch:** chore/merge-fixes-p0-p1
**PR:** #84

## Context

Post-merge follow-up fixes from PR #83 review. Reviewer identified 1 CRITICAL and 6 HIGH issues.

## Decisions

### H1 — `_hasFreeTrial` locale fix: **DEFERRED**

`SubscriptionPackage` exposes only `introductoryPriceString` (localized display string). Fixing locale-safety requires adding a `double? introductoryPrice` field to the entity + regenerating freezed + updating mapper — scope creep that delays shipping the CRITICAL fix.

**Decision:** Add `// TODO(locale)` comment + track as separate ticket. Current app targets a narrow market; cosmetic label mismatch is low-probability, low-impact.

## Fixes In Scope

### CRITICAL — OPTIONS preflight handler (verify-google-purchase)

**File:** `supabase/functions/verify-google-purchase/index.ts`

`handleCorsIfPreflight` exists in `_shared/cors.ts` but is not imported or called. Browser OPTIONS preflight hits the `req.method !== "POST"` guard → 405 → preflight fails → POST blocked.

**Fix:** Add preflight guard as first statement in `Deno.serve`:
```typescript
import { corsHeaders, handleCorsIfPreflight } from "../_shared/cors.ts";
// ...
Deno.serve(async (req) => {
  const preflight = handleCorsIfPreflight(req);
  if (preflight) return preflight;
  // ... rest of handler
```

### H2 — Mock interface instead of concrete class

**File:** `test/features/subscription/presentation/screens/paywall_screen_test.dart`

`MockSubscriptionRepository implements SubscriptionRepository` (concrete) → should implement `ISubscriptionRepository` (interface). Fixes domain/data boundary in tests.

### H3 — authViewModelProvider not overridden in paywall tests

**File:** `test/features/subscription/presentation/screens/paywall_screen_test.dart`

`subscriptionNotifierProvider` reads `authViewModelProvider` internally. Not overriding it creates implicit Supabase dependency. Fix: add `authViewModelProvider.overrideWith(MockAuthViewModel.new)` to `buildWidget()`, mirroring `home_screen_test.dart` pattern.

### H4 — _handlePurchase untested (5 branches)

**File:** `test/features/subscription/presentation/screens/paywall_screen_test.dart`

Add `group('_handlePurchase', ...)` covering:
1. No package selected → button disabled (already partially covered, verify)
2. Purchase cancelled (`PaymentException(code: 'user_cancelled')`) → no snackbar
3. Purchase error (non-cancel) → error snackbar
4. Purchase success but subscription inactive → warning snackbar
5. Purchase success + active → success snackbar + screen pops

### H1 — TODO comment

**File:** `lib/features/subscription/presentation/screens/paywall_screen.dart`

Add `// TODO(locale): introductoryPriceString is device-locale-dependent...` to `_hasFreeTrial`.

## Testing

- `flutter test test/features/subscription/` — all pass
- `flutter analyze` — zero warnings

## Out of Scope

- GPA regex tightening (MEDIUM, security-only, separate PR)
- Gradient color tokenization (MEDIUM, pre-existing)
- Home screen test strengthening (MEDIUM, separate PR)
