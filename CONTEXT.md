# 📌 Artio Project — System Context & Living Spec (CONTEXT.md)

> **Cập nhật lần cuối:** 2026-08-29 (cron-job.org Keep-Alive 24/7 & Project Skills Added)  
> **Workspace:** `/Users/mini4/bydone/newartio`  
> **Package Name:** `com.artio.artio`  
> **GitHub Remote:** `https://github.com/jokerlin135/artio.git`  
> **Phiên bản:** 1.0.0+18  

---

## 1. 🏗️ Tổng quan Dự án & Kiến trúc (Architecture)

**Artio** là ứng dụng AI Art & Image Generation đa nền tảng (Flutter Mobile + Flutter Web Admin) tích hợp Supabase Backend, AI Generation Pipelines (Gemini / KIE), In-App Subscriptions (RevenueCat) và AdMob Monetization.

### Tech Stack
* **Client App:** Flutter 3.41+ (Dart 3.11+), State Management với `flutter_riverpod` + `riverpod_generator`, Models với `freezed` & `json_serializable`, Routing với `go_router`.
* **Admin Dashboard (`admin/`):** Flutter Web Admin quản lý templates, prompt ordering, user credits và analytics.
* **Backend & DB:** Supabase (PostgreSQL 17 on AWS Singapore `ap-southeast-1`), Row Level Security (RLS), Supabase Storage (`generated-images`), Supabase Edge Functions (Deno / TypeScript).
* **AI Generation:** Edge Function `generate-image` tích hợp Google Gemini API & KIE API.
* **Monetization:** `purchases_flutter` (RevenueCat) cho Subscriptions (Pro / Ultra) + `google_mobile_ads` (AdMob Rewarded Ads nhận credit).

---

## 2. ⚡ Tài nguyên Supabase & CI/CD / Keep-Alive Đã Thiết Lập

* **Tài khoản Supabase:** `acc4` (`olivia.davis.9752013c@monet.uno`)
* **Project Ref:** `gbmemcsxkqdhzlxivopj` (`msupa-prod-a`)
* **Trạng thái:** 🟢 **ACTIVE_HEALTHY** *(Đã kiểm tra REST API, OpenAPI Schema và PostgreSQL Connection Pooler)*
* **API URL:** `https://gbmemcsxkqdhzlxivopj.supabase.co`
* **Direct DB Host:** `db.gbmemcsxkqdhzlxivopj.supabase.co:5432`
* **AWS Pooler Host:** `aws-0-ap-southeast-1.pooler.supabase.com:6543` (Transaction) / `5432` (Session)
* **GitHub Repository:** `jokerlin135/artio` (Đã cấu hình GitHub Secrets `SUPABASE_URL` và `SUPABASE_ANON_KEY`).
* **Cron-job.org Keep-Alive (Chính):**
  * Job 1 (DB Wakeup): ID `8347394` — `Artio - Supabase PostgreSQL DB Keep-Alive` (Query `/rest/v1/templates?select=id&limit=1` mỗi 4 giờ lúc 00:15, 04:15, 08:15, 12:15, 16:15, 20:15).
  * Job 2 (Auth Ping): ID `8347395` — `Artio - Supabase Auth Service Ping` (Query `/auth/v1/settings` mỗi 6 giờ lúc 02:30, 08:30, 14:30, 20:30).
* **GitHub Actions Keep-Alive (Dự phòng):** `.github/workflows/supabase-keepalive.yml` chạy mỗi 4 ngày.

### Database Schema Đã Deploy:
1. `templates`: Đã nạp đầy đủ **38 AI Art Templates** (Cyberpunk, Anime, Vintage, Oil Painting, 3D Render, v.v.).
2. `profiles`: Quản lý user, role (`user`/`admin`), subscription tier (`free`/`pro`/`ultra`).
3. `user_credits` & `credit_transactions`: Hệ thống credit tiêu chuẩn, trừ credit khi generate, cộng credit khi xem ad hoặc mua gói.
4. `generation_jobs`: Theo dõi trạng thái tiến trình tạo ảnh real-time.
5. `pending_ad_rewards` & `ad_views`: Chống gian lận xem quảng cáo bằng cơ chế Server-side Nonce và giới hạn 10 ads/ngày.
6. `generation_rate_limits`: Chống spam tạo ảnh đồng thời.
7. Storage Bucket: `generated-images` đã được khởi tạo.

---

## 3. 🔍 Pre-check Đánh giá Toàn diện (Quality & Readiness Audit)

| Tiêu chí | Trạng thái | Đánh giá & Bằng chứng thực nghiệm |
|---|:---:|---|
| **Logic & Code Health** | 🟢 **PASSED** | Toàn bộ **772 tests** (758 mobile + 14 admin) pass 100%. `flutter analyze` đạt **0 issues** trên cả mobile `lib/` và `admin/`. |
| **Workflow & Pipeline** | 🟢 **PASSED** | Luồng Onboarding ➡️ Template Detail / Custom Prompt ➡️ Credit Check ➡️ AI Inference ➡️ Storage Upload ➡️ Realtime Gallery hiển thị hoàn chỉnh. |
| **Security & Gitignore** | 🟢 **PASSED** | `.gitignore` được cấu hình nghiêm ngặt: Chặn tất cả `.env*`, `*.jks`, `*.keystore`, credentials, binary nặng (`apk`, `aab`, `mp4`). |
| **Keep-Alive & CI/CD** | 🟢 **PASSED** | GitHub Secrets đã set, workflow 3 tầng sẵn sàng chạy cron 4 ngày/lần. |
| **AdMob Production** | 🟢 **PASSED** | App ID `ca-app-pub-4985902269618783~7949221597` & Unit ID `ca-app-pub-4985902269618783/6913130654` đã cập nhật. |
| **Legal Pages** | 🟢 **PASSED** | Live tại `https://ainear.github.io/artio-legal/` (Privacy, Terms, Account Deletion). |
| **AI Agents & Skills** | 🟢 **PASSED** | Cấu hình `.agent/` và `.agents/` đầy đủ 22 agents + 47 skills được lưu giữ và cho phép commit. |

---

## 4. ❌ Tính năng Cần Hoàn Thiện Tiếp theo & Rủi ro Tiềm ẩn

### 🔴 P0 — Blocking Release (Cần làm trước khi xuất xưởng):
1. **Deploy Supabase Edge Functions:** Deploy 6 functions (`generate-image`, `reward-ad`, `delete-account`, `sync-subscription`, `verify-google-purchase`, `revenuecat-webhook`) lên project `gbmemcsxkqdhzlxivopj` và set Edge Secrets.
2. **Google Play Console App & Subscriptions:** Tạo App ID `com.artio.artio` và tạo 4 Subscription Products (`artio_pro_monthly`, `artio_pro_yearly`, `artio_ultra_monthly`, `artio_ultra_yearly`).
3. **RevenueCat ↔ Google Play Link:** Upload Service Account JSON (`artio-revenuecat-2026-dbb0b33e49f9.json`) vào RevenueCat Dashboard để kết nối Google Play Billing.

### ⚠️ Rủi ro & Chiến lược Phòng ngừa (Risk & Mitigation):
* **Rủi ro Supabase Free-Tier Auto-Pause (7 ngày inactive):**
  * *Giải pháp:* Đã thiết lập GitHub Actions Workflow `supabase-keepalive.yml` query bảng thật `templates` mỗi 4 ngày.
* **Rủi ro rò rỉ Service Role Key:**
  * *Giải pháp:* `SUPABASE_SERVICE_ROLE_KEY` chỉ cấu hình trong Supabase Edge Functions Secrets, tuyệt đối không đưa vào client mobile bundle.

---

## 5. 🌿 Quy tắc Quản lý Nhánh & Backup / Rollback Strategy

1. **Nhánh chính (`main`):** Luôn giữ ở trạng thái ổn định, build được và pass toàn bộ test suite.
2. **Phát triển tính năng mới:**
   * Với các tính năng lớn (ví dụ: bổ sung model AI mới, Webhook thanh toán Stripe): Tạo branch mới `feature/<ten-tinh-nang>`, hoàn thiện và merge PR vào `main`.
   * Với các chỉnh sửa nhỏ/fix cấu hình: Có thể commit trực tiếp lên `main` sau khi chạy `flutter analyze` và `flutter test`.
3. **Cập nhật `CONTEXT.md`:** Luôn cập nhật lại file này mỗi khi có thay đổi kiến trúc hoặc trước khi kết thúc session làm việc.

