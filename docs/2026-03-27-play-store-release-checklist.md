# Play Store Release Checklist — Artio
> Ngày: 2026-03-27 | Mục tiêu: Publish internal test release lên Google Play

---

## Mục tiêu

Chuẩn bị đầy đủ để submit Artio lên Google Play Console — bắt đầu từ **Internal Testing**, tiến tới **Production**.

---

## 1. Kỹ thuật — Blockers đã fix

### ✅ INTERNET permission (FIXED — 2026-03-27)

**Vấn đề:** `android.permission.INTERNET` chỉ có trong `src/debug/` và `src/profile/`. Release build không có permission này → toàn bộ network call thất bại.

**Fix:** Thêm vào `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## 2. Kỹ thuật — Còn tồn đọng (phải fix trước public release)

### 🔴 AdMob App ID vẫn là test ID

**File:** `android/app/src/main/AndroidManifest.xml` dòng 44
**Giá trị hiện tại:** `ca-app-pub-3940256099942544~3347511713` (Google test publisher)
**Cần thay bằng:** App ID thật từ [AdMob Console](https://apps.admob.com)

Sau khi có ID thật:
1. Cập nhật `AndroidManifest.xml` meta-data
2. Cập nhật `.env.production`:
   ```
   ADMOB_ANDROID_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX
   ```

### 🟡 AdMob Rewarded Ad Unit ID vẫn là test ID

**File:** `lib/core/services/rewarded_ad_service.dart` dòng 17
```dart
const _prodAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917'; // ← test ID
```
**Cần thay bằng:** Ad unit ID thật từ AdMob Console sau khi app được approve.

### 🟡 RevenueCat Apple Key chưa điền

**File:** `.env.production`
```
# TODO(#68): Replace Apple key with real appl_xxx from RevenueCat Dashboard
REVENUECAT_APPLE_KEY=...
```
Chỉ ảnh hưởng iOS. Android đã có Google key ✓.

---

## 3. Signing & Build

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| Keystore file | ✅ Có | `android/app/artio-upload.jks` (git-ignored) |
| `local.properties` | ✅ Đủ | `storeFile`, `storePassword`, `keyAlias`, `keyPassword` |
| `build.gradle.kts` signingConfig | ✅ Đúng | Đọc từ `local.properties` |
| versionCode / versionName | ✅ `18 / 1.0.0` | Cập nhật trong `pubspec.yaml` khi cần |
| applicationId | ✅ `com.artio.artio` | Nhất quán |
| flutter analyze lib/ | ✅ No issues | Chỉ admin/ có lỗi `gap` package |

**Lệnh build release AAB:**
```bash
flutter build appbundle \
  --release \
  --dart-define=ENV=production \
  --obfuscate \
  --split-debug-info=build/symbols
```

---

## 4. Play Store Listing — Nội dung

### Short Description (78/80 ký tự)
```
AI image generator with 18+ models — Imagen, Flux, GPT Image & more.
```

### Full Description
```
Artio — AI Art Generator

Turn your ideas into stunning images with the most powerful AI models available today. Whether you're a creative professional or just exploring, Artio makes AI image generation fast, beautiful, and accessible.

🎨 GENERATE FROM TEXT OR PHOTO
• Type a prompt and generate in seconds
• Choose from 18+ AI models including Imagen 4 Ultra, Flux-2 Pro, GPT Image 1.5, Gemini 3 Pro, and Seedream 4.5
• Use templates to create stunning effects without writing prompts
• Select aspect ratios: 1:1, 4:3, 16:9, 9:16, 3:4

🖼️ GALLERY & SHARING
• Browse all your creations in a beautiful masonry gallery
• Download images directly to your device
• Share with one tap

⭐ PRO SUBSCRIPTION
• Unlimited credits
• Access to all AI models at max quality
• No ads
• Priority generation queue
• Early access to new features

🎁 FREE TO START
• 5 free credits daily — no sign-up required to explore
• Earn extra credits by watching rewarded ads
• Top up credits with one-time purchases

🔒 YOUR PRIVACY
• Images stored securely in your personal account
• No images used for AI training
• Full data control with account deletion

Artio supports Google Sign-In for quick and secure access.
```

---

## 5. Assets — Trạng thái

| Asset | Yêu cầu | Trạng thái | File |
|---|---|---|---|
| App icon | 512×512 PNG, RGB, không alpha | ✅ Tạo xong | `assets/ic_launcher_512.png` |
| Feature graphic | 1024×500 px | ❌ Cần thiết kế | `assets/feature.png` (851×315 — sai size) |
| Screenshots | 2–8 ảnh Android, min 1080×1920 | ❌ Cần chụp từ device | — |

### Ghi chú feature graphic
File hiện có `assets/feature.png` là 851×315 px — **không đúng kích thước**. Cần export lại đúng 1024×500 px. Nội dung gợi ý: background tối gradient + logo Artio + tagline + mockup màn hình app.

### Ghi chú screenshots
Cần chụp **ít nhất 2, tối đa 8** screenshot từ Android device/emulator:
- Portrait: 1080×1920 px (hoặc 2160×3840)
- Gợi ý màn hình: Create, Gallery, Templates, Paywall, Settings

---

## 6. Data Safety Form (Play Console)

### Dữ liệu được collect

| Data type | Mục đích | Chia sẻ với ai |
|---|---|---|
| Email address | Account / Authentication | Không |
| User ID | App functionality | Không |
| Purchase history | Subscription & credits | Google Play (RevenueCat) |
| Generated images | User content storage | Không |
| Crash logs | Bug fixing (Sentry) | Sentry |
| Device info | Diagnostics (Sentry) | Sentry |
| Ad interactions | Rewarded ads (AdMob) | Google (AdMob) |

### Câu trả lời checkbox

- ✅ **Personal info** → Email address (collected, not shared)
- ✅ **Financial info** → Purchase history (collected, shared with payment processor)
- ✅ **Photos & videos** → User-generated images (collected, not shared)
- ✅ **App activity** → App interactions (collected, shared with Sentry)
- ✅ **App info & performance** → Crash logs (collected, shared with Sentry)
- ✅ **Device or other IDs** → AdMob device ID (collected, shared with Google)

### Câu hỏi Yes/No

| Câu hỏi | Trả lời |
|---|---|
| Data encrypted in transit? | **Yes** (HTTPS only) |
| User can request data deletion? | **Yes** (có tính năng account deletion trong Settings) |
| Complies with Families Policy? | No (app not targeting children) |

---

## 7. Content Rating (IARC)

Trả lời khi điền questionnaire trên Play Console:

| Câu hỏi | Trả lời |
|---|---|
| Violence | None |
| Sexual content | None |
| Profanity | None |
| Controlled substance | None |
| Horror | None |
| User-generated content (text/images) | **Yes** |
| Shares user location | No |
| In-app purchases | **Yes** |
| Gambling | No |

→ **Kết quả dự kiến:** Everyone hoặc Teen
→ **Lưu ý:** Vì có UGC (ảnh AI), Google có thể hỏi về content moderation policy. Chuẩn bị câu trả lời: app không cho phép lưu/chia sẻ content vi phạm, có cơ chế report.

---

## 8. Target Audience

**Đề xuất: 13+**

Lý do: có in-app purchase + user-generated content. Nếu muốn khai "All ages", cần bổ sung cơ chế kiểm duyệt nội dung nghiêm hơn.

---

## 9. Checklist Upload lên Play Console

### Internal Testing (bước đầu)

- [ ] Build AAB release (`flutter build appbundle --release --dart-define=ENV=production`)
- [ ] Upload AAB lên Play Console > Internal Testing
- [ ] Điền Store Listing: title, short desc, full desc
- [ ] Upload app icon `assets/ic_launcher_512.png`
- [ ] Upload ít nhất 2 screenshots
- [ ] Upload feature graphic 1024×500 (cần làm mới)
- [ ] Điền Content Rating questionnaire
- [ ] Điền Data Safety form
- [ ] Khai báo target audience (13+)
- [ ] Thêm Privacy Policy URL: `https://ainear.github.io/artio-legal/privacy.html`
- [ ] Khai báo in-app purchases (RevenueCat subscriptions + credit packs)
- [ ] Add testers (email)

### Trước Production

- [ ] Thay AdMob App ID thật vào `AndroidManifest.xml` + `.env.production`
- [ ] Thay Rewarded Ad Unit ID thật vào `rewarded_ad_service.dart`
- [ ] Bump `versionCode` trong `pubspec.yaml`
- [ ] Pass Play Store Pre-launch report (không có crash)
