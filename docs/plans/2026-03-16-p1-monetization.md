# P1: Monetization Improvements — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Tăng paywall conversion rate và tăng credit visibility để users biết credit status trước khi bị chặn.

**Architecture:** Toàn bộ thay đổi trong Flutter layer. Không cần backend. RevenueCat SDK cung cấp `introductoryPrice` field trên `Package` object. Credit balance đã có `creditBalanceProvider` — chỉ cần wire vào Home AppBar.

**Tech Stack:** Flutter, Riverpod, RevenueCat SDK (`purchases_flutter`), `lib/features/subscription/presentation/screens/paywall_screen.dart`, `lib/features/template_engine/presentation/screens/home_screen.dart`

---

### Task 1: Auto-select Recommended Plan trong Paywall

**Files:**
- Modify: `lib/features/subscription/presentation/screens/paywall_screen.dart`
- Test: `test/features/subscription/presentation/screens/paywall_screen_test.dart` (tạo mới nếu chưa có)

**Context:** Hiện tại `_selectedPackage` khởi tạo là `null` → CTA button disabled với text "Select a plan above". User phải tap thủ công. Auto-select Ultra (non-pro, recommended) giảm friction.

**Step 1: Đọc hiện trạng**

File: `lib/features/subscription/presentation/screens/paywall_screen.dart:22`

Hiện tại:
```dart
SubscriptionPackage? _selectedPackage;
```

**Step 2: Thêm `_initSelectedPackage` method**

Trong `_PaywallScreenState`, thêm sau `SubscriptionPackage? _selectedPackage;`:

```dart
// Auto-selects the recommended (Ultra/non-pro) plan when offerings load.
void _initSelectedPackage(List<SubscriptionPackage> packages) {
  if (_selectedPackage != null || packages.isEmpty) return;
  final recommended = packages.firstWhere(
    (p) => !p.identifier.startsWith('artio_pro_'),
    orElse: () => packages.first,
  );
  setState(() => _selectedPackage = recommended);
}
```

**Step 3: Gọi `_initSelectedPackage` trong `_buildContent`**

Tìm method `_buildContent` (dòng ~44):
```dart
Widget _buildContent(
  BuildContext context,
  List<SubscriptionPackage> packages,
  AsyncValue<SubscriptionStatus> subscription,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
```

Thêm call ngay sau `final isDark`:
```dart
  // Auto-select recommended plan on first load.
  _initSelectedPackage(packages);
```

**Step 4: Chạy flutter analyze**

```bash
flutter analyze lib/features/subscription/presentation/screens/paywall_screen.dart
```

Expected: `No issues found!`

**Step 5: Commit**

```bash
git add lib/features/subscription/presentation/screens/paywall_screen.dart
git commit -m "feat(paywall): auto-select recommended Ultra plan on load"
```

---

### Task 2: Free Trial Display (Apple Guideline 3.1.1 compliant)

**Files:**
- Modify: `lib/features/subscription/presentation/screens/paywall_screen.dart`
- Modify: `lib/features/subscription/domain/entities/subscription_package.dart` (check if `introductoryPrice` exposed)

**Context:** Apple 3.1.1 yêu cầu: nếu package có free trial, paywall PHẢI hiển thị duration + post-trial price TRƯỚC khi user tap Subscribe. RevenueCat `SubscriptionPackage` wraps RC `Package` — check `storeProduct.introductoryPrice`.

**Step 1: Kiểm tra SubscriptionPackage entity**

```bash
cat lib/features/subscription/domain/entities/subscription_package.dart
```

Xem `SubscriptionPackage` có expose `introductoryPrice` không. Nếu không, cần thêm.

**Step 2: Thêm `trialPeriod` getter vào `SubscriptionPackage` (nếu chưa có)**

Nếu `SubscriptionPackage` wrap RC `Package`:
```dart
// Trong subscription_package.dart hoặc extension
String? get introductoryPriceString {
  // RC Package có storeProduct.introductoryPrice?.priceString
  // Tùy thuộc vào cách SubscriptionPackage được define
  return null; // placeholder — implement theo actual RC API
}
```

> **Note:** Đọc `lib/features/subscription/domain/entities/subscription_package.dart` để xem RC Package được wrap như thế nào trước khi implement. Nếu `SubscriptionPackage` có `rcPackage` field hoặc tương đương, dùng `rcPackage.storeProduct.introductoryPrice`.

**Step 3: Thêm helper `_trialText` trong `_PaywallScreenState`**

```dart
/// Returns trial display text if package has introductory offer, null otherwise.
/// Format: "7 days free, then $9.99/month"
String? _trialText(SubscriptionPackage pkg) {
  final intro = pkg.introductoryPrice; // adjust field name per actual impl
  if (intro == null) return null;
  final period = pkg.identifier.contains('monthly') ? 'month' : 'year';
  return '${intro.periodNumberOfUnits} ${intro.periodUnit.name.toLowerCase()}s free, '
      'then ${pkg.priceString}/$period. Cancel anytime.';
}
```

**Step 4: Update `_buildBottomCTA` — đổi button text + thêm trial terms**

Tìm trong `_buildBottomCTA` (dòng ~491):
```dart
child: const Text(
  'Subscribe Now',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  ),
),
```

Thay bằng:
```dart
child: Text(
  _selectedPackage != null && _trialText(_selectedPackage!) != null
      ? 'Start Free Trial'
      : 'Subscribe Now',
  style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  ),
),
```

**Step 5: Thêm trial terms text bên dưới button (Apple 3.1.1 required)**

Sau `_buildComplianceText(context)` trong `_buildBottomCTA`:
```dart
// Sau SizedBox(height: AppSpacing.xs):
if (_selectedPackage != null) ...[
  Builder(
    builder: (context) {
      final trial = _trialText(_selectedPackage!);
      if (trial == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          trial,
          textAlign: TextAlignAlign.center,
          style: const TextStyle(
            color: AppColors.primaryCta,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    },
  ),
],
```

**Step 6: Chạy analyze + commit**

```bash
flutter analyze lib/features/subscription/presentation/screens/paywall_screen.dart
git add lib/features/subscription/
git commit -m "feat(paywall): display free trial terms per Apple guideline 3.1.1"
```

---

### Task 3: Annual Plan Savings Badge

**Files:**
- Modify: `lib/features/subscription/presentation/screens/paywall_screen.dart` (method `_buildPlanCard`)

**Context:** Nếu RC có yearly package, hiển thị "Save X%" badge. Cần tính monthly equivalent của yearly price để so sánh.

**Step 1: Thêm helper `_savingsPercent`**

Thêm vào `_PaywallScreenState`:
```dart
/// Calculates savings % for a yearly package vs its monthly equivalent.
/// Returns null if not a yearly package or no monthly counterpart.
int? _savingsPercent(SubscriptionPackage pkg, List<SubscriptionPackage> all) {
  if (!pkg.identifier.contains('yearly')) return null;
  // Find monthly counterpart (same tier)
  final tierPrefix = pkg.identifier.contains('artio_pro_') ? 'artio_pro_' : 'artio_ultra_';
  final monthly = all.where(
    (p) => p.identifier.startsWith(tierPrefix) && p.identifier.contains('monthly'),
  ).firstOrNull;
  if (monthly == null) return null;

  final monthlyTotal = monthly.price * 12;
  if (monthlyTotal <= 0) return null;
  final savings = ((monthlyTotal - pkg.price) / monthlyTotal * 100).round();
  return savings > 0 ? savings : null;
}
```

> **Note:** `SubscriptionPackage.price` cần là `double`. Kiểm tra entity — nếu chỉ có `priceString`, cần thêm `price` field từ RC `Package.storeProduct.price`.

**Step 2: Update `_buildPlanCard` — thêm savings badge**

Tìm trong `_buildPlanCard` dòng có `if (isRecommended) ...` (dòng ~284), thêm savings badge sau:

```dart
// Sau block if (isCurrentPlan):
Builder(
  builder: (context) {
    // packages cần được pass vào method — xem step 3
    final savings = _savingsPercent(pkg, _allPackages);
    if (savings == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Save $savings%',
        style: const TextStyle(
          color: Colors.green,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  },
),
```

**Step 3: Lưu packages list vào state**

Trong `_buildContent`, lưu packages:
```dart
// Thêm field trong _PaywallScreenState:
List<SubscriptionPackage> _allPackages = [];

// Trong _buildContent, sau _initSelectedPackage:
_allPackages = packages;
```

Pass `_allPackages` vào `_buildPlanCard` thay vì access trực tiếp.

**Step 4: Analyze + commit**

```bash
flutter analyze lib/features/subscription/presentation/screens/paywall_screen.dart
git add lib/features/subscription/presentation/screens/paywall_screen.dart
git commit -m "feat(paywall): show yearly savings badge on annual plan cards"
```

---

### Task 4: Credit Balance Chip trên Home AppBar

**Files:**
- Modify: `lib/features/template_engine/presentation/screens/home_screen.dart`
- Test: `test/features/template_engine/presentation/screens/home_screen_test.dart` (tạo mới)

**Context:** Home screen dùng `CustomScrollView` với `SliverToBoxAdapter` header — không có AppBar. Credit chip sẽ được thêm vào phần Header row (dòng ~42-60) bên cạnh greeting text.

**Step 1: Đọc home_screen.dart đầy đủ**

```bash
cat lib/features/template_engine/presentation/screens/home_screen.dart
```

Xác định vị trí của `Row` chứa greeting (khoảng dòng 43).

**Step 2: Thêm import providers**

Thêm vào đầu file:
```dart
import 'package:artio/features/credits/presentation/providers/credit_balance_provider.dart';
import 'package:artio/routing/routes/app_routes.dart';
```

**Step 3: Thêm `_CreditChip` widget**

Tạo private widget cuối file `home_screen.dart`:
```dart
class _CreditChip extends ConsumerWidget {
  const _CreditChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(creditBalanceProvider);
    return balanceAsync.when(
      data: (balance) => GestureDetector(
        onTap: () => const CreditHistoryRoute().push<void>(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.white10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.white20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💎', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                '$balance',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

**Step 4: Thêm `_CreditChip` vào Header Row**

Tìm `Row` greeting trong `HomeScreen.build` (khoảng dòng 43):
```dart
Row(
  children: [
    Expanded(
      child: Column(...)
    ),
    // Thêm vào đây:
    const _CreditChip(),
  ],
),
```

**Step 5: Viết test**

File: `test/features/template_engine/presentation/screens/home_screen_test.dart`

```dart
import 'package:artio/features/credits/presentation/providers/credit_balance_provider.dart';
import 'package:artio/features/template_engine/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeScreen credit chip', () {
    testWidgets('shows credit balance when loaded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creditBalanceProvider.overrideWith((_) => Stream.value(42)),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('hides chip while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creditBalanceProvider.overrideWith(
              (_) => const Stream.empty(),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('💎'), findsNothing);
    });
  });
}
```

**Step 6: Chạy test**

```bash
flutter test test/features/template_engine/presentation/screens/home_screen_test.dart -v
```

Expected: All tests PASS

**Step 7: Commit**

```bash
git add lib/features/template_engine/presentation/screens/home_screen.dart
git add test/features/template_engine/presentation/screens/home_screen_test.dart
git commit -m "feat(home): add credit balance chip to home header"
```

---

### Task 5: Low Credit Warning Banner

**Files:**
- Modify: `lib/features/template_engine/presentation/screens/home_screen.dart`
- Modify test: `test/features/template_engine/presentation/screens/home_screen_test.dart`

**Context:** Chỉ show banner khi balance < 20 VÀ user không phải subscriber. Subscriber có unlimited credits theo plan, không cần warning.

**Step 1: Thêm import subscription provider vào home_screen.dart**

```dart
import 'package:artio/core/state/subscription_state_provider.dart';
```

**Step 2: Thêm `_LowCreditBanner` widget**

```dart
class _LowCreditBanner extends ConsumerWidget {
  const _LowCreditBanner();

  static const _threshold = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(creditBalanceProvider).valueOrNull;
    final isSubscriber = ref.watch(subscriptionNotifierProvider)
        .valueOrNull
        ?.isActive ?? false;

    if (isSubscriber) return const SizedBox.shrink();
    if (balance == null || balance >= _threshold) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Only $balance credits left. Watch an ad or upgrade to keep creating.',
              style: const TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => const PaywallRoute().push<void>(context),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFFF6B35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 3: Thêm `_LowCreditBanner` vào CustomScrollView — sau Header, trước template grid**

Trong `CustomScrollView.slivers`, thêm `SliverToBoxAdapter` sau header section:
```dart
// Sau SliverToBoxAdapter chứa Header:
const SliverToBoxAdapter(child: _LowCreditBanner()),
```

**Step 4: Thêm tests**

Append vào `test/features/template_engine/presentation/screens/home_screen_test.dart`:
```dart
group('HomeScreen low credit banner', () {
  testWidgets('shows banner when balance < 20 and not subscriber', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creditBalanceProvider.overrideWith((_) => Stream.value(5)),
          subscriptionNotifierProvider.overrideWith(
            (_) => // mock returning isActive: false state
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('credits left'), findsOneWidget);
  });

  testWidgets('hides banner when subscriber even if low credits', (tester) async {
    // ... subscriber override → expect banner not shown
  });

  testWidgets('hides banner when balance >= 20', (tester) async {
    // ... balance=50 → banner not shown
  });
});
```

> **Note:** Xem `test/` directory để biết pattern mock `subscriptionNotifierProvider` — dùng `mocktail` theo CLAUDE.md convention.

**Step 5: Chạy tests**

```bash
flutter test test/features/template_engine/presentation/screens/home_screen_test.dart -v
flutter analyze
```

**Step 6: Commit**

```bash
git add lib/features/template_engine/presentation/screens/home_screen.dart
git add test/features/template_engine/presentation/screens/home_screen_test.dart
git commit -m "feat(home): show low credit warning banner for free users"
```

---

## Final Verification — P1

```bash
flutter analyze
flutter test
# Expected: No issues, all tests pass

# Manual QA:
# 1. Open paywall → Ultra plan auto-selected, button enabled immediately ✅
# 2. If RC has trial → button shows "Start Free Trial" + "X days free, then $Y/month" ✅
# 3. Yearly package (if available) → "Save X%" badge visible ✅
# 4. Home screen → credit chip top-right showing balance → tap → goes to credit history ✅
# 5. Free user with < 20 credits → orange banner visible ✅
# 6. Subscriber → no banner ✅
```
