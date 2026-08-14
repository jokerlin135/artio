# Design: UI Insets Fix + Paywall App Store Compliance

**Date:** 2026-03-15
**Branch:** `fix/ui-insets-paywall-compliance`
**Scope:** Flutter main app only — no backend changes

---

## Problem Statement

On Android gesture navigation devices (e.g. Samsung A53), bottom system UI (gesture bar ~48dp)
covers interactive elements in several screens and bottom sheets:

1. **InsufficientCreditsSheet** — Upgrade/Dismiss buttons hidden behind gesture bar
2. **PremiumModelSheet** — Upgrade button hidden
3. **PaywallScreen** — Subscribe CTA button hidden
4. **AuthGateSheet** — No safe area handling

Additionally, the Paywall screen is missing required disclosures per App Store Review
Guideline 3.1.1 and Google Play Billing Policy.

---

## Audit Results

### 🔴 CRITICAL

| File | Issue |
|------|-------|
| `insufficient_credits_sheet.dart` | No SafeArea, `EdgeInsets.all(24px)` fixed — buttons cut off |
| `premium_model_sheet.dart` | No SafeArea, `8px` hardcoded — Upgrade button hidden |
| `paywall_screen.dart` | SafeArea present but CTA uses `AppSpacing.xl` (32px) fixed, no `viewPadding.bottom` |

### ⚠️ MEDIUM

| File | Issue |
|------|-------|
| `auth_gate_sheet.dart` | No SafeArea in bottom sheet |
| `onboarding_screen.dart` | Redundant `SizedBox(height: 48)` inside SafeArea — double-spacing |
| `template_detail_screen.dart` | Static 16px padding, no dynamic bottom inset |

### 🏪 Policy Violations

| Policy | Requirement | Current Status |
|--------|-------------|----------------|
| App Store 3.1.1 | Auto-renewal disclosure with period and price | ❌ Missing |
| App Store 3.1.1 | Terms of Service + Privacy Policy links in paywall | ❌ Missing |
| Google Play Billing | Clear subscription terms before purchase | ❌ Insufficient |
| Both | Trial period explicitly stated if applicable | ❌ Not shown |
| Both | Interactive elements must be tappable (not obscured) | ❌ Failing |

---

## Design

### Section 1: Standardized Bottom Sheet Pattern

Create a shared `BottomSheetBody` widget in `lib/core/widgets/`:

```dart
class BottomSheetBody extends StatelessWidget {
  const BottomSheetBody({required this.child, this.padding, super.key});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: (padding ?? EdgeInsets.all(AppSpacing.lg)).copyWith(
          bottom: (padding?.bottom ?? AppSpacing.lg) + bottomInset,
        ),
        child: child,
      ),
    );
  }
}
```

**Apply to:**
- `insufficient_credits_sheet.dart` — replace root `Padding` with `BottomSheetBody`
- `premium_model_sheet.dart` — replace root `Padding` with `BottomSheetBody`
- `auth_gate_sheet.dart` — replace root `Padding` with `BottomSheetBody`

**Fix directly (not via widget):**
- `paywall_screen.dart` → bottom CTA container: add `+ MediaQuery.of(context).viewPadding.bottom` to bottom padding
- `onboarding_screen.dart` → remove redundant `SizedBox(height: 48)` inside SafeArea

### Section 2: Paywall Compliance Redesign

**2a — Trial badge (dynamic)**

Add badge above plan cards, shown only when RevenueCat offering has `introductoryPrice`:

```
┌─────────────────────────────────────┐
│  🎉 Start with a 3-day free trial   │  ← shown dynamically
└─────────────────────────────────────┘
```

Source: `package.introductoryPrice?.periodNumberOfUnits` from RevenueCat SDK.

**2b — Auto-renewal disclosure block (required)**

Add below plan cards, above Subscribe button:

```
By subscribing, you agree to our Terms of Service and Privacy Policy.
Subscription auto-renews unless cancelled at least 24 hours before
the end of the current period. Manage or cancel anytime in
your device's account settings.
```

- "Terms of Service" → `launchInAppUrl(context, 'https://artio.app/terms')`
- "Privacy Policy" → `launchInAppUrl(context, 'https://artio.app/privacy')`
- Font: `AppTypography.captionMuted` — small but legible, not hidden

**2c — CTA bottom padding fix**

```dart
// Before
padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),

// After
padding: EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.md,
  AppSpacing.lg,
  AppSpacing.xl + MediaQuery.of(context).viewPadding.bottom,
),
```

**2d — "Cancel anytime" text**

Increase visibility: use `AppTypography.caption` (not `captionMuted`) with slightly higher contrast.

### Section 3: Branch & Test Plan

**Branch:** `fix/ui-insets-paywall-compliance` from `main`

**Test cases:**

| # | Scenario | Device | Expected |
|---|----------|--------|----------|
| 1 | Tap generate with 0 credits → InsufficientCreditsSheet | Samsung A53 | Upgrade + Dismiss fully visible |
| 2 | Select premium model without sub → PremiumModelSheet | Samsung A53 | Upgrade button fully visible |
| 3 | Tap generate without login → AuthGateSheet | Samsung A53 | Sheet content fully visible |
| 4 | Open paywall from Settings → Manage/Upgrade Plan | Samsung A53 | Subscribe button fully visible |
| 5 | Open paywall from insufficient credits sheet | Samsung A53 | CTA not obscured |
| 6 | Scroll paywall to bottom | Any | Auto-renewal disclosure + Terms/Privacy links visible |
| 7 | Paywall with trial offering | Any | Trial badge shown; without trial → badge hidden |
| 8 | Run onboarding flow | Any | No double-spacing at bottom |
| 9 | Widget tests for `BottomSheetBody` | CI | Pass |
| 10 | `flutter analyze` | CI | 0 warnings |

**Scope NOT changing:**
- IAP logic, RevenueCat integration, credit flow
- Backend / Edge Functions
- Overall color scheme / layout of paywall
- Any other features

---

## Files to Change

| File | Change Type |
|------|-------------|
| `lib/core/widgets/bottom_sheet_body.dart` | NEW — shared widget |
| `lib/features/credits/presentation/widgets/insufficient_credits_sheet.dart` | Use `BottomSheetBody` |
| `lib/features/credits/presentation/widgets/premium_model_sheet.dart` | Use `BottomSheetBody` |
| `lib/features/create/presentation/widgets/auth_gate_sheet.dart` | Use `BottomSheetBody` |
| `lib/features/subscription/presentation/screens/paywall_screen.dart` | Fix CTA padding + add compliance text + trial badge |
| `lib/features/auth/presentation/screens/onboarding_screen.dart` | Remove redundant SizedBox(height: 48) |
| `test/core/widgets/bottom_sheet_body_test.dart` | NEW — widget tests |
| `test/features/subscription/presentation/screens/paywall_screen_test.dart` | Add compliance text tests |
