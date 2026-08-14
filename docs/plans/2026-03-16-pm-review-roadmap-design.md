# PM Review Roadmap — Design Doc
**Date:** 2026-03-16
**Scope:** Store submission blockers + monetization + retention improvements
**Approach:** 3 independent plans (Approach B), execute in order P0 → P1 → P2

---

## Context

Từ PM + Tester review toàn diện, phát hiện:
- P0: Store submission blockers (ATT, Privacy/ToS URLs, Data Safety declarations)
- P1: Monetization gaps (paywall UX, free trial display, credit visibility)
- P2: Retention gaps (gallery, share, push notifications, profile photo)

AdMob production IDs và iOS IAP (Issue #68) được defer riêng — không trong scope này.

---

## Plan A — P0: Store Submission Blockers

**Goal:** Unblock App Store + Play Store submission. Zero new features.

### Tasks

#### 1. ATT Consent Screen (iOS)
- Package: `app_tracking_transparency`
- Show prompt TRƯỚC khi `MobileAds.instance.initialize()` trong `main.dart`
- Handle `TrackingStatus.denied` gracefully (AdMob chạy limited ads, không crash)
- Thêm `NSUserTrackingUsageDescription` vào `Info.plist`

#### 2. GitHub Pages — Privacy Policy + Terms of Service
- Tạo repo `artio-legal` trên GitHub (hoặc dùng `monet88.github.io/artio-legal/`)
- Deploy 2 file HTML: `privacy.html`, `terms.html`
- Cập nhật URLs trong `paywall_screen.dart` (`_buildComplianceText`) — hiện là `artio.app/privacy` và `artio.app/terms`
- Cập nhật URLs trong `settings_sections.dart` (Legal section)

#### 3. Checklist Manual (không phải code)
- Play Store: Điền Data Safety Form (khai báo: email, generated images, purchase history, device ID)
- App Store: Điền Privacy Nutrition Labels (same categories)
- Rebuild AAB sau khi có ATT code

### Policy compliance
- ATT: Apple App Tracking Transparency framework ✅
- GitHub Pages URLs: Accepted by both stores ✅

---

## Plan B — P1: Monetization Improvements

**Goal:** Tăng paywall conversion rate. Chủ yếu Flutter UI changes + RevenueCat data.

### Tasks

#### 1. Auto-select Recommended Plan
- `paywall_screen.dart`: Thay `SubscriptionPackage? _selectedPackage = null`
- Init `_selectedPackage` = package đầu tiên trong list khi `offeringsProvider` load xong
- Ultra (non-pro) là recommended → dùng `packages.firstWhere((p) => !p.identifier.startsWith('artio_pro_'), orElse: () => packages.first)`

#### 2. Free Trial Display (Apple Guideline 3.1.1 compliant)
- Check `pkg.introductoryPrice` từ RevenueCat SDK
- Nếu có trial: đổi CTA button text thành "Start Free Trial"
- Bắt buộc thêm text bên dưới CTA: "X days free, then $Y/month. Cancel anytime."
- Nếu không có trial: giữ nguyên "Subscribe Now"

#### 3. Annual Plan Savings Badge
- Tính savings % từ yearly vs monthly price (RevenueCat `price` field)
- Hiển thị badge "Save X%" trên plan card nếu package là yearly
- Chỉ tính nếu cả monthly lẫn yearly cùng tier available

#### 4. Credit Balance on Home AppBar
- Thêm `creditBalanceProvider` watch vào Home screen
- Hiển thị chip `💎 {balance}` ở trailing AppBar
- Tap chip → navigate to `CreditHistoryRoute`

#### 5. Low Credit Warning Banner
- Threshold: balance < 20 credits
- Show `MaterialBanner` hoặc colored chip đỏ/cam trên Home
- Chỉ show nếu không phải subscriber (subscriber có unlimited)

### Policy compliance
- Free trial display bắt buộc có terms text (Apple 3.1.1) ✅ được handle trong task 2
- Không có dark patterns: user phải tap xác nhận purchase ✅

---

## Plan C — P2: Retention Improvements

**Goal:** Tăng D7/D30 retention. Core retention loop.

### Tasks

#### 1. Generation Gallery / History Screen
- Route mới: `GalleryRoute` → `GalleryScreen`
- Query `generation_jobs` table: `select * from generation_jobs where user_id = auth.uid() order by created_at desc`
- UI: Grid 2 cột, thumbnail từ Supabase Storage URL
- Tap → full-screen viewer với share button
- Pagination: load 20 items, infinite scroll

#### 2. Share to Social
- Package: `share_plus` (add to `pubspec.yaml`)
- iOS: thêm `NSPhotoLibraryUsageDescription` vào `Info.plist`
- Android 13+: thêm `READ_MEDIA_IMAGES` permission vào `AndroidManifest.xml`
- Share từ: result screen sau generation + gallery viewer
- Share image (download từ Storage URL) + optional caption "Created with Artio"

#### 3. Push Notifications (Generation Complete + Low Credits)
- Package: `firebase_messaging`
- Firebase project đã có (Supabase auth provider) → enable FCM
- Lưu FCM token vào `profiles` table (migration: thêm column `fcm_token text`)
- Edge Function trigger: sau khi `generate-image` complete → call FCM send API
- Notification types: "Your image is ready!" + "You're running low on credits"
- iOS: request permission trước khi subscribe (standard FCM flow)

#### 4. Profile Photo Upload
- Unchecked trong PDR FR-1
- `image_picker` package (đã có hoặc add)
- Upload đến Supabase Storage bucket `avatars/{user_id}/avatar.jpg`
- Cập nhật `profiles.avatar_url` sau upload
- Hiển thị trong `UserProfileCard` widget (settings screen)

#### 5. Onboarding Use-Case Selection (Slide mới)
- Thêm slide 0: "What will you create?" với 4 options (Social Media / Business / Personal / Just Exploring)
- Store selection vào `SharedPreferences` (không cần backend)
- Dùng để personalize slide 3 subtitle (optional, không phức tạp hóa)

### Policy compliance
- `share_plus`: cần photo library permission → được handle trong task 2 ✅
- FCM: iOS yêu cầu explicit permission → standard FCM flow ✅
- Profile photo: cần `NSPhotoLibraryUsageDescription` → handled ✅

---

## AI Content Filtering (Out of scope — flag riêng)

Risk: Apple/Google yêu cầu NSFW content filtering. `generate-image` edge function hiện chưa có server-side filter rõ ràng. Cần sprint riêng sau P2 để assess và implement nếu cần.

---

## Execution Order

```
P0 (1 sprint) → Submit stores → P1 (1 sprint) → P2 (2 sprints)
```

P0 phải xong trước khi submit. P1/P2 có thể develop trước submit nhưng không block nhau.
