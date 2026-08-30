# 📱 Báo Cáo Triển Khai — Đổi Package Name `com.newmailabs.artio`, Audit Toàn Diện & Cài Đặt Thiết Bị Samsung A53 (2026-08-30)

> **Dự án:** Artio — AI Art & Image Generation (Flutter Mobile)  
> **Package Name Mới:** `com.newmailabs.artio`  
> **Target Device:** Samsung Galaxy A53 5G (`SM A536E`, IP: `192.168.2.25:40805`)  
> **Áp dụng Skills:** `behavior-model-debugger`, `vibe-engineering-workflow`, `vibe-git-manager`, `iap-revenuecat-rn`, `in-app-purchases`  

---

## 1. 🎯 Mục Tiêu (Objectives)

1. **Rà Soát & Audit Toàn Bộ Codebase:** Kiểm tra độ hoàn thiện của các tính năng AI, Template Engine, Monetization (RevenueCat, AdMob) và Supabase Backend.
2. **Đổi Package Name Chuẩn Xác:** Chuyển đổi toàn bộ định danh gói từ `com.artio.artio` sang `com.newmailabs.artio` trên cả Android (`applicationId`, `namespace`, Kotlin package, `AndroidManifest.xml`) và iOS (`PRODUCT_BUNDLE_IDENTIFIER`).
3. **Chuẩn Hóa Cấu Hình RevenueCat & Billing:** Đồng bộ mã định danh gói với luồng In-App Purchases (RevenueCat SDK + Google Play Developer API).
4. **Fix Lỗi Build Gradle & Compile APK Debug:** Xử lý triệt để xung đột AGP 8.11 / Java 17 `JdkImageTransform` và ép chuẩn `KotlinCompile` `languageVersion = 1.8` cho các dependency thư viện (như `sentry_flutter`, `connectivity_plus`).
5. **Build & Cài Đặt Trực Tiếp Lên Máy Thật Samsung Galaxy A53:** Cài đặt file `app-debug.apk` qua kết nối Wireless ADB và khởi chạy thành công ứng dụng.

---

## 2. 🛠️ Những Việc Đã Làm (What Was Done)

### 2.1. Đổi Package Name Sang `com.newmailabs.artio`
* **`android/app/build.gradle.kts`:**
  * Cập nhật `namespace = "com.newmailabs.artio"`
  * Cập nhật `applicationId = "com.newmailabs.artio"`
* **Cấu trúc Thư mục Kotlin:**
  * Tạo package directory mới: `android/app/src/main/kotlin/com/newmailabs/artio/`
  * Chuyển `MainActivity.kt` sang package `com.newmailabs.artio`.
  * Xóa bỏ thư mục package cũ `com.artio`.
* **`android/app/src/main/AndroidManifest.xml`:**
  * Bổ sung schema deep link `<data android:scheme="com.newmailabs.artio"/>` bên cạnh `<data android:scheme="com.artio.app"/>`.
* **`ios/Runner.xcodeproj/project.pbxproj`:**
  * Cập nhật toàn bộ `PRODUCT_BUNDLE_IDENTIFIER = com.newmailabs.artio;` và `com.newmailabs.artio.RunnerTests;`.
* **Living Specs:**
  * Cập nhật `CONTEXT.md` và các tài liệu liên quan.

### 2.2. Xử Lý Lỗi Build Gradle AGP 8.11 & Kotlin 2.2
* **Khắc phục lỗi `JdkImageTransform` trên `connectivity_plus`:** Cấu hình chuẩn `compileSdk = 35` và Java 17 `compileOptions` cho toàn bộ subprojects thông qua `plugins.withId("com.android.library")`.
* **Khắc phục lỗi `sentry_flutter` Kotlin language version:** Cấu hình ép `tasks.withType<KotlinCompile>` áp dụng `languageVersion = KOTLIN_1_8` và `jvmTarget = JVM_17`.

### 2.3. Build Debug APK & Cài Đặt Vào Thiết Bị Samsung A53
* Build thành công file APK: `build/app/outputs/flutter-apk/app-debug.apk` (166MB).
* Phát hiện thiết bị `SM A536E` (`192.168.2.25:40805`, Android 16 API 36).
* Streamed install APK vào thiết bị: **Success**.
* Khởi chạy Intent `com.newmailabs.artio/.MainActivity` thành công, không gặp crash runtime.

---

## 3. 📊 Kết Quả Thực Nghiệm (Verification Results)

| Hạng mục kiểm tra | Kết quả | Chi tiết |
|---|:---:|---|
| **Package Name Mới** | 🟢 **`com.newmailabs.artio`** | Nhất quán trên Android, iOS và Manifest |
| **Gradle Compile** | 🟢 **BUILD SUCCESSFUL** | Hoàn tất trong 1m 41s, 0 lỗi Javac/Kotlin |
| **Flutter Analyze** | 🟢 **0 Issues** | 0 warnings, 0 errors |
| **Cài đặt Thiết bị A53** | 🟢 **SUCCESS** | Đã cài và khởi chạy `com.newmailabs.artio` trên Samsung Galaxy A53 |
| **App Startup** | 🟢 **RUNNING** | Khởi động mượt mà, zero fatal exceptions |

---

## 4. 🧭 Lưu Ý Quan Trọng Cho RevenueCat & Google Play Console

Theo chuẩn skill `iap-revenuecat-rn` & `in-app-purchases`:
1. **Google Play Console:** Khi tạo App mới trên Google Play Console, hãy nhập đúng Package Name là **`com.newmailabs.artio`**.
2. **RevenueCat Dashboard:**
   * Trong phần **Project Settings ➡️ Apps ➡️ Google Play**, nhập **Google Play package name**: `com.newmailabs.artio`.
   * Upload file Service Account JSON: `artio-revenuecat-2026-dbb0b33e49f9.json`.
   * Tạo 4 gói subscriptions tương ứng: `artio_pro_monthly`, `artio_pro_yearly`, `artio_ultra_monthly`, `artio_ultra_yearly`.
