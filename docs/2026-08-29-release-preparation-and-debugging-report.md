# 📋 Báo Cáo Tổng Hợp — Behavioral Debugging, Keep-Alive 24/7 & Chuẩn Bị Release (2026-08-29)

> **Dự án:** Artio — AI Art & Image Generation App (Flutter Mobile + Flutter Web Admin)  
> **Workspace:** `/Users/mini4/bydone/newartio`  
> **Ngày thực hiện:** 2026-08-29  
> **Áp dụng Skills:** `behavior-model-debugger`, `vibe-engineering-workflow`, `vibe-git-manager`, `keeping-supabase-alive`, `in-app-purchases`, `google-play-publishing`  

---

## 1. 🎯 Mục Tiêu (Objectives)

1. **Nạp & Đồng bộ Bộ Skills Mới Vào Project Scope:** Bổ sung `vibe-engineering-workflow`, `vibe-git-manager`, `behavior-model-debugger`, `keeping-supabase-alive` vào `.agent/skills/` và `.agents/skills/`.
2. **Nâng Cấp Hạ Tầng Supabase Keep-Alive 24/7/365:** Chuyển đổi từ GitHub Actions (dễ bị dừng sau 60 ngày không commit) sang giải pháp `console.cron-job.org` API với key quản lý tập trung từ `~/.zshrc`.
3. **Chẩn Đoán Mô Hình Hành Vi Người Dùng (Behavioral Model Debugger):** Tái cấu trúc "Luật chơi" (Invariants & Mental Model), phát hiện và sửa dứt điểm các lỗi va chạm logic giữa các hệ thống độc lập.
4. **Rà Soát Toàn Diện Trước Khi Release (Store Submission Readiness):** Chuẩn bị đầy đủ cấu hình Google Play Console Subscriptions, RevenueCat In-App Purchases, và Supabase Edge Functions.

---

## 2. 🛠️ Những Việc Đã Làm (What Was Done)

### 2.1. Nạp Skills & Thiết Lập cron-job.org Keep-Alive 24/7
- **Sao chép Skills:** Đã copy 4 bộ skill chuyên sâu từ `/Users/mini4/Downloads/ASkills` và `~/.gemini/config/skills/` vào cả `.agent/skills/` và `.agents/skills/`.
- **Cấu hình `.env.local`:** Tạo file cấu hình môi trường local (được `.gitignore` bảo vệ tuyệt đối) chứa `SUPABASE_URL`, `SUPABASE_ANON_KEY`, và `CRONJOB_API` (`ifNq9IqaM+qyyQ5MDRqGsNIbMIUzHrayuezRwcPwpqM=`).
- **Tự động hóa đăng ký Job qua API:** Viết script `scripts/setup_cronjob_keepalive.py` và kích hoạt 2 Cron Jobs độc lập trên `console.cron-job.org`:
  * **Job 1 (DB Query Wakeup):** ID `8347394` — `Artio - Supabase PostgreSQL DB Keep-Alive` (Query `/rest/v1/templates?select=id&limit=1` mỗi 4 giờ lúc 00:15, 04:15, 08:15, 12:15, 16:15, 20:15).
  * **Job 2 (Auth Service Ping):** ID `8347395` — `Artio - Supabase Auth Service Ping` (Query `/auth/v1/settings` mỗi 6 giờ lúc 02:30, 08:30, 14:30, 20:30).

### 2.2. Chẩn Đoán & Sửa Lỗi Mô Hình Hành Vi (Behavioral Debugging)
- **Fix 1 — Đồng bộ Insufficient Credits Sheet cho Template Flow:**
  * *Vấn đề:* Khi tài khoản hết credits (< 4), `CreditCheckPolicy` từ chối nhưng `GenerationViewModel` ném `Exception` thường, khiến UI `TemplateDetailScreen` kiểm tra `error is PaymentException` bị sai $\rightarrow$ không hiện BottomSheet nạp credits.
  * *Xử lý:* Cập nhật `lib/features/template_engine/presentation/view_models/generation_view_model.dart` đóng gói chuẩn `AppException.payment(message: reason, code: 'insufficient_credits')`.
  * *Kiểm thử:* Bổ sung 2 test cases trong `generation_view_model_test.dart`.
- **Fix 2 — Quản lý Timer trong ImageViewer:**
  * *Vấn đề:* `ImageViewerPage` dùng `Future.delayed(3s)` không lưu `Timer`, khiến khi quẹt ảnh nhanh liên tục xảy ra xung đột trigger animation fade-out.
  * *Xử lý:* Bổ sung `Timer? _indicatorTimer`, gọi `_indicatorTimer?.cancel()` trước khi tạo timer mới và cancel trong `dispose()`.

### 2.3. Cập Nhật Living Spec & Git Baseline
- Cập nhật `CONTEXT.md` và `implementation_notes.html`.
- Commit và push sạch sẽ lên GitHub `https://github.com/jokerlin135/artio.git` (`branch main`).

---

## 3. 📊 Kết Quả Đạt Được (Results & Verification Metrics)

| Hạng mục kiểm tra | Kết quả | Chi tiết thực nghiệm |
|---|:---:|---|
| **Mobile Tests** | 🟢 **PASS** | **759 / 759 tests pass** (100%) |
| **Admin Tests** | 🟢 **PASS** | **14 / 14 tests pass** (100%) |
| **Static Code Analysis** | 🟢 **0 Issues** | `flutter analyze` 0 warnings / errors |
| **cron-job.org Keep-Alive** | 🟢 **24/7 ACTIVE** | Job `8347394` & `8347395` phản hồi HTTP 200 |
| **Supabase Database** | 🟢 **HEALTHY** | PostgreSQL 17 active trên project `gbmemcsxkqdhzlxivopj` |
| **Git Repository** | 🟢 **Clean & Synced** | Zero secret leak, đã push lên `origin main` |

---

## 4. 🧭 Hướng Dẫn & Kế Hoạch Triển Khai Tiếp Theo (IAP & Play Store Publishing)

### 🔹 Bước 1: Thiết Lập 4 Gói Subscription Trên Google Play Console
1. Đăng nhập [Google Play Console](https://play.google.com/console) ➡️ Chọn ứng dụng `Artio` (`com.artio.artio`).
2. Vào mục **Monetize** ➡️ **Products** ➡️ **Subscriptions**.
3. Tạo 4 sản phẩm theo đúng Product ID chuẩn trong codebase:
   * `artio_pro_monthly` (Gói Pro 1 Tháng)
   * `artio_pro_yearly` (Gói Pro 1 Năm)
   * `artio_ultra_monthly` (Gói Ultra 1 Tháng)
   * `artio_ultra_yearly` (Gói Ultra 1 Năm)
4. Thiết lập Base Plan và Pricing tương ứng.

### 🔹 Bước 2: Kết Nối RevenueCat Với Google Play Service Account
1. Đăng nhập [RevenueCat Dashboard](https://app.revenuecat.com/) ➡️ Chọn Project Artio.
2. Vào **Project Settings** ➡️ **Apps** ➡️ Chọn **Google Play**.
3. Upload file Service Account JSON: `artio-revenuecat-2026-dbb0b33e49f9.json` (Email: `artio-play-validator@artio-revenuecat-2026.iam.gserviceaccount.com`).
4. Cấu hình **Entitlements**:
   * `pro` $\rightarrow$ Gán gói `artio_pro_monthly`, `artio_pro_yearly`.
   * `ultra` $\rightarrow$ Gán gói `artio_ultra_monthly`, `artio_ultra_yearly`.
5. Cấu hình **Webhook**: Trỏ về `https://gbmemcsxkqdhzlxivopj.supabase.co/functions/v1/revenuecat-webhook`.

### 🔹 Bước 3: Deploy 6 Supabase Edge Functions & Set Secrets
Deploy các functions lên project `gbmemcsxkqdhzlxivopj`:
```bash
supabase functions deploy generate-image       --no-verify-jwt --project-ref gbmemcsxkqdhzlxivopj
supabase functions deploy reward-ad            --no-verify-jwt --project-ref gbmemcsxkqdhzlxivopj
supabase functions deploy delete-account       --no-verify-jwt --project-ref gbmemcsxkqdhzlxivopj
supabase functions deploy verify-google-purchase --no-verify-jwt --project-ref gbmemcsxkqdhzlxivopj
supabase functions deploy sync-subscription    --no-verify-jwt --project-ref gbmemcsxkqdhzlxivopj
supabase functions deploy revenuecat-webhook   --no-verify-jwt --project-ref gbmemcsxkqdhzlxivopj
```
Set Secrets:
```bash
supabase secrets set GEMINI_API_KEY="..." KIE_API_KEY="..." SUPABASE_SERVICE_ROLE_KEY="..." REVENUECAT_WEBHOOK_SECRET="..." --project-ref gbmemcsxkqdhzlxivopj
```

### 🔹 Bước 4: Build Release AAB & Upload Play Console
```bash
make build-android
```
Upload `build/app/outputs/bundle/release/app-release.aab` lên track **Internal Testing**.
