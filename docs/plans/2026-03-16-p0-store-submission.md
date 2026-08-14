# P0: Store Submission Blockers — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unblock App Store + Play Store submission bằng cách tạo Privacy/ToS pages và update URLs trong app.

**Architecture:** ATT đã implement xong trong `main.dart`. Chỉ còn 2 việc: (1) tạo GitHub Pages cho legal pages, (2) update hardcoded URLs trong Flutter code. Không cần thay đổi backend hay logic app.

**Tech Stack:** HTML (GitHub Pages), Flutter (url update), Git

---

## Tình trạng ban đầu (đã done — KHÔNG cần làm lại)

- ✅ `app_tracking_transparency` package — trong `pubspec.yaml`
- ✅ `_requestAttIfNeeded()` — `main.dart:22-37`, gọi trước `MobileAds.instance.initialize()`
- ✅ `NSUserTrackingUsageDescription` — `ios/Runner/Info.plist`
- ✅ Gallery feature, Share feature — đã implement đầy đủ

---

### Task 1: Tạo GitHub Pages repo cho Privacy Policy + Terms of Service

**Files:**
- Create: repo mới `artio-legal` trên GitHub (ngoài codebase)
- Create: `index.html`
- Create: `privacy.html`
- Create: `terms.html`

**Step 1: Tạo repo GitHub**

```bash
# Dùng GitHub acc monet88 (từ feedback memory)
gh repo create monet88/artio-legal --public --description "Artio legal pages"
cd /tmp && mkdir artio-legal && cd artio-legal && git init
git remote add origin https://github.com/monet88/artio-legal.git
```

**Step 2: Tạo file `privacy.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Artio — Privacy Policy</title>
  <style>
    body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #333; }
    h1 { color: #1a1a2e; } h2 { color: #2d2d5e; margin-top: 32px; }
    a { color: #6c63ff; }
  </style>
</head>
<body>
  <h1>Privacy Policy</h1>
  <p><strong>Effective date:</strong> March 16, 2026</p>
  <p>Artio ("we", "us", or "our") is committed to protecting your privacy. This policy explains how we collect, use, and share information when you use our app.</p>

  <h2>1. Information We Collect</h2>
  <ul>
    <li><strong>Account information:</strong> Email address when you register.</li>
    <li><strong>Generated content:</strong> Images you create are stored in our servers to show in your gallery.</li>
    <li><strong>Purchase information:</strong> Subscription status and transaction IDs (processed via RevenueCat / Google Play / App Store).</li>
    <li><strong>Device identifiers:</strong> Advertising ID (with your consent via ATT on iOS) for personalized ads via Google AdMob.</li>
    <li><strong>Usage data:</strong> App events and crash reports via Sentry.</li>
  </ul>

  <h2>2. How We Use Your Information</h2>
  <ul>
    <li>To provide, maintain, and improve the Artio service.</li>
    <li>To process subscriptions and manage credits.</li>
    <li>To serve relevant ads (with consent) or non-personalized ads (without consent).</li>
    <li>To send transactional notifications (generation complete, low credits).</li>
  </ul>

  <h2>3. Data Sharing</h2>
  <p>We do not sell your personal data. We share data only with service providers:</p>
  <ul>
    <li><strong>Supabase</strong> — Database and storage (EU region)</li>
    <li><strong>RevenueCat</strong> — Subscription management</li>
    <li><strong>Google AdMob</strong> — Advertising</li>
    <li><strong>Sentry</strong> — Crash reporting</li>
  </ul>

  <h2>4. Data Retention</h2>
  <p>We retain your account data and generated images until you delete your account. You may request deletion at any time by contacting us.</p>

  <h2>5. Children's Privacy</h2>
  <p>Artio is not directed to children under 13. We do not knowingly collect personal information from children.</p>

  <h2>6. Contact</h2>
  <p>For privacy inquiries: <a href="mailto:support@artio.app">support@artio.app</a></p>
</body>
</html>
```

**Step 3: Tạo file `terms.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Artio — Terms of Service</title>
  <style>
    body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #333; }
    h1 { color: #1a1a2e; } h2 { color: #2d2d5e; margin-top: 32px; }
    a { color: #6c63ff; }
  </style>
</head>
<body>
  <h1>Terms of Service</h1>
  <p><strong>Effective date:</strong> March 16, 2026</p>
  <p>By using Artio, you agree to these Terms of Service. Please read them carefully.</p>

  <h2>1. Account</h2>
  <p>You must create an account to use Artio. You are responsible for maintaining the security of your account and all activity under it.</p>

  <h2>2. Credits and Subscriptions</h2>
  <ul>
    <li>Free users receive 10 welcome credits and may earn additional credits by watching rewarded ads (up to 10 ads per day).</li>
    <li>Premium subscriptions (Pro, Ultra) are billed monthly or annually via Google Play or App Store.</li>
    <li>Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.</li>
    <li>Credits are non-transferable and have no cash value.</li>
  </ul>

  <h2>3. Content</h2>
  <ul>
    <li>You retain ownership of images you generate using Artio.</li>
    <li>You may not use Artio to generate illegal, harmful, or NSFW content.</li>
    <li>We reserve the right to remove content that violates these terms.</li>
  </ul>

  <h2>4. Prohibited Uses</h2>
  <p>You may not: reverse engineer the app, abuse the credit system, use automated tools to generate images at scale, or violate any applicable laws.</p>

  <h2>5. Disclaimers</h2>
  <p>Artio is provided "as is." We do not guarantee uninterrupted service or specific output quality from AI models.</p>

  <h2>6. Changes</h2>
  <p>We may update these terms at any time. Continued use of Artio after changes constitutes acceptance.</p>

  <h2>7. Contact</h2>
  <p>For questions: <a href="mailto:support@artio.app">support@artio.app</a></p>
</body>
</html>
```

**Step 4: Tạo `index.html` redirect**

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Artio Legal</title>
</head>
<body>
  <h2>Artio Legal</h2>
  <ul>
    <li><a href="privacy.html">Privacy Policy</a></li>
    <li><a href="terms.html">Terms of Service</a></li>
  </ul>
</body>
</html>
```

**Step 5: Deploy GitHub Pages**

```bash
git add . && git commit -m "feat: add Artio Privacy Policy and Terms of Service"
git push -u origin main

# Enable GitHub Pages:
# GitHub → monet88/artio-legal → Settings → Pages → Source: Deploy from branch → main / root → Save
# URL sẽ là: https://monet88.github.io/artio-legal/
```

**Step 6: Verify URLs live**

```
https://monet88.github.io/artio-legal/privacy.html  → 200 OK
https://monet88.github.io/artio-legal/terms.html    → 200 OK
```

---

### Task 2: Update URLs trong Flutter app

**Files:**
- Modify: `lib/features/subscription/presentation/screens/paywall_screen.dart:385,395`
- Modify: `lib/features/settings/presentation/widgets/settings_sections.dart` (Legal section)

**Step 1: Tìm và thay URL trong paywall**

File: `lib/features/subscription/presentation/screens/paywall_screen.dart`

Tìm (dòng ~385-395 trong `_buildComplianceText`):
```dart
onTap: () => launchInAppUrl(context, 'https://artio.app/terms'),
```
```dart
onTap: () => launchInAppUrl(context, 'https://artio.app/privacy'),
```

Thay bằng:
```dart
onTap: () => launchInAppUrl(context, 'https://monet88.github.io/artio-legal/terms.html'),
```
```dart
onTap: () => launchInAppUrl(context, 'https://monet88.github.io/artio-legal/privacy.html'),
```

**Step 2: Tìm URLs trong settings_sections.dart**

```bash
grep -n "artio.app\|privacy\|terms" lib/features/settings/presentation/widgets/settings_sections.dart
```

Tìm tất cả URLs trong Legal section và thay bằng GitHub Pages URLs tương ứng.

**Step 3: Viết test verify URL constants**

```bash
# Không cần unit test cho URL string change. Chạy analyze để đảm bảo không lỗi:
flutter analyze
```

Expected: `No issues found!`

**Step 4: Commit**

```bash
git add lib/features/subscription/presentation/screens/paywall_screen.dart
git add lib/features/settings/presentation/widgets/settings_sections.dart
git commit -m "fix(legal): update Privacy Policy and ToS URLs to GitHub Pages"
```

---

### Task 3: Manual Submission Checklist (không phải code)

Đây là các bước manual cần thực hiện trên store dashboards. Không cần code thay đổi.

**Play Store — Data Safety Form**
- Google Play Console → App content → Data safety
- Khai báo:
  - **Personal info → Email address**: Collected, not shared, required for account creation
  - **Photos and videos → Photos**: Generated images stored on servers, user choice
  - **App activity → App interactions**: Crash reports (Sentry)
  - **Device or other IDs → Device or other IDs**: Advertising ID (with consent)
  - **Financial info → Purchase history**: Subscription status via Google Play
- Data encrypted in transit: ✅ Yes (HTTPS)
- Users can request deletion: ✅ Yes (contact support)

**App Store — Privacy Nutrition Labels**
- App Store Connect → App Privacy → Privacy Practices
- Data used to track you: Advertising ID (if ATT granted)
- Data linked to you: Email, Purchase history, Photos (generated images)
- Data not linked to you: Crash data (Sentry)

**Rebuild AAB sau khi Task 2 hoàn thành:**

```bash
flutter build appbundle --release --dart-define=ENV=production
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Verification

Sau khi hoàn thành tất cả tasks:

```bash
flutter analyze
# Expected: No issues found!

# Mở app → Settings → Privacy Policy → mở đúng trang GitHub Pages ✅
# Mở app → Paywall → scroll xuống → tap Terms → đúng trang ✅
# Mở app trên iOS simulator → lần đầu: ATT dialog xuất hiện ✅
```
