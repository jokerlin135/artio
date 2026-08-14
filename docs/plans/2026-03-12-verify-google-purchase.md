# verify-google-purchase Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a `verify-google-purchase` Supabase edge function that validates Google Play subscription purchases directly — bypassing RevenueCat server validation — then updates Supabase `is_premium` and grants credits automatically.

**Architecture:** Flutter app extracts the raw purchase token from RC SDK after a successful purchase, then calls the new `verify-google-purchase` edge function. The edge function authenticates with Google Play Publisher API using a service account JWT, validates the token, and on success calls `update_subscription_status` + `grant_subscription_credits` (idempotent via orderId). RC SDK still handles client-side UI. RC webhook still handles renewals/cancellations whenever it starts working.

**Tech Stack:** Deno/TypeScript (edge function), Google Play Android Publisher API v3, service account JWT (RS256), Dart/Flutter (subscription_repository + subscription_provider), Supabase RPC.

---

## Pre-requisite: Dashboard Setup (BẠN LÀM TRƯỚC)

### Bước 1: Tạo Service Account trong GCP Console

1. Vào https://console.cloud.google.com → project `artio-revenuecat-2026`
2. IAM & Admin → Service Accounts → **+ CREATE SERVICE ACCOUNT**
3. Name: `artio-play-validator`
4. Description: `Validates Google Play purchases for Artio app`
5. Click **CREATE AND CONTINUE** → skip optional steps → **DONE**
6. Click vào service account vừa tạo → **KEYS** tab → **ADD KEY** → **Create new key** → JSON → **CREATE**
7. Download file JSON (sẽ dùng ở bước 3)

### Bước 2: Grant Play Console Access

1. Vào https://play.google.com/console → **Setup** → **API access**
2. Phần **Service accounts** → tìm `artio-play-validator@artio-revenuecat-2026.iam.gserviceaccount.com`
   - Nếu không thấy: click **Grant access** → nhập email service account
3. Click **Grant access** → chọn permissions:
   - ✅ **View app information and download bulk reports**
   - ✅ **View financial data, orders, and cancellation survey responses**
   - ✅ **Manage orders and subscriptions**
4. Save

### Bước 3: Set Supabase Secret

Mở JSON key file vừa download, copy toàn bộ nội dung, rồi chạy:

```bash
# Thay <JSON_CONTENT> bằng nội dung file JSON (1 dòng, escape quotes)
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='<JSON_CONTENT>' --project-ref kytbmplsazsiwndppoji
```

Verify:
```bash
supabase secrets list --project-ref kytbmplsazsiwndppoji | grep GOOGLE_PLAY
```
Expected: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON | <digest>`

---

## Task 1: Build verify-google-purchase Edge Function

**Files:**
- Create: `supabase/functions/verify-google-purchase/index.ts`

### Step 1: Tạo file edge function

```typescript
// supabase/functions/verify-google-purchase/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")!;

const PACKAGE_NAME = "com.artio.artio";

/** Map product ID prefix → tier name + credits */
function getTierInfo(productId: string): { tier: string; credits: number } | null {
  if (productId.startsWith("artio_ultra_")) return { tier: "ultra", credits: 500 };
  if (productId.startsWith("artio_pro_")) return { tier: "pro", credits: 200 };
  return null;
}

/** Generate a Google OAuth2 access token using service account JWT (RS256). */
async function getGoogleAccessToken(): Promise<string> {
  const sa = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const signingInput = `${encode(header)}.${encode(payload)}`;

  // Import RSA private key
  const pemBody = sa.private_key
    .replace("-----BEGIN RSA PRIVATE KEY-----", "")
    .replace("-----END RSA PRIVATE KEY-----", "")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const jwt = `${signingInput}.${sigB64}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    throw new Error(`Google OAuth2 token error: ${err}`);
  }
  const { access_token } = await tokenRes.json() as { access_token: string };
  return access_token;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Authenticate user via JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Parse request body
  let purchaseToken: string;
  let productId: string;
  try {
    const body = await req.json() as { purchaseToken?: string; productId?: string };
    purchaseToken = body.purchaseToken ?? "";
    productId = body.productId ?? "";
    if (!purchaseToken || !productId) throw new Error("missing fields");
  } catch {
    return new Response(JSON.stringify({ error: "Body must include purchaseToken and productId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const tierInfo = getTierInfo(productId);
  if (!tierInfo) {
    return new Response(JSON.stringify({ error: `Unknown productId: ${productId}` }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    // Call Google Play Publisher API
    const accessToken = await getGoogleAccessToken();
    const gpUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;
    const gpRes = await fetch(gpUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!gpRes.ok) {
      const errBody = await gpRes.text();
      console.error("[verify-google-purchase] Google Play API error:", gpRes.status, errBody);
      return new Response(JSON.stringify({ error: "Google Play validation failed", detail: errBody }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    const gpData = await gpRes.json() as {
      purchaseState?: number; // 0=purchased, 1=cancelled, 2=pending
      orderId?: string;
      expiryTimeMillis?: string;
      startTimeMillis?: string;
    };

    console.log(`[verify-google-purchase] GP response for ${user.id}: state=${gpData.purchaseState} orderId=${gpData.orderId}`);

    // purchaseState: 0 = active purchase
    if (gpData.purchaseState !== 0 && gpData.purchaseState !== undefined) {
      return new Response(JSON.stringify({
        verified: false,
        reason: `purchaseState=${gpData.purchaseState}`,
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const orderId = gpData.orderId ?? purchaseToken; // fallback to token if no orderId
    const expiresAt = gpData.expiryTimeMillis
      ? new Date(Number(gpData.expiryTimeMillis)).toISOString()
      : null;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // Update subscription status
    const { error: statusErr } = await supabase.rpc("update_subscription_status", {
      p_user_id: user.id,
      p_is_premium: true,
      p_tier: tierInfo.tier,
      p_expires_at: expiresAt,
    });
    if (statusErr) {
      console.error("[verify-google-purchase] update_subscription_status error:", statusErr);
      return new Response(JSON.stringify({ error: "Failed to update subscription status" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Grant credits (idempotent via orderId — same orderId RC webhook uses as transaction_id)
    const { error: creditErr } = await supabase.rpc("grant_subscription_credits", {
      p_user_id: user.id,
      p_amount: tierInfo.credits,
      p_description: `${tierInfo.tier} subscription — verified via Google Play API`,
      p_reference_id: `gp-${orderId}`,
    });
    if (creditErr) {
      console.error("[verify-google-purchase] grant_subscription_credits error:", creditErr);
      // Don't fail — subscription status already updated
    }

    console.log(`[verify-google-purchase] Verified ${user.id}: tier=${tierInfo.tier}, ${tierInfo.credits} credits, orderId=${orderId}`);

    return new Response(JSON.stringify({
      verified: true,
      tier: tierInfo.tier,
      credits: tierInfo.credits,
      orderId,
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[verify-google-purchase] Unexpected error:", err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
```

### Step 2: Deploy edge function

```bash
cd /Users/mini4/1space/artio
supabase functions deploy verify-google-purchase --project-ref kytbmplsazsiwndppoji
```
Expected: `Deployed Function verify-google-purchase on project kytbmplsazsiwndppoji`

### Step 3: Commit

```bash
git add supabase/functions/verify-google-purchase/index.ts
git commit -m "feat(verify-google-purchase): new edge function to validate GP purchases directly"
```

---

## Task 2: Modify subscription_repository.dart — Extract Purchase Token

**Files:**
- Modify: `lib/features/subscription/data/repositories/subscription_repository.dart`

**Context:** Sau khi `Purchases.purchase()` trả về `PurchaseResultInfo`, `result.transaction?.transactionIdentifier` trên Android = purchase token cần để call Google Play API.

### Step 1: Đọc file hiện tại

```bash
cat lib/features/subscription/data/repositories/subscription_repository.dart
```

### Step 2: Sửa method `purchase()` — thêm call tới verify-google-purchase

Tìm đoạn hiện tại (dòng 56-86):
```dart
@override
Future<SubscriptionStatus> purchase(SubscriptionPackage package) async {
  try {
    final nativePkg = package.nativePackage as Package;
    final result = await Purchases.purchase(
      PurchaseParams.package(nativePkg),
    );
    return _mapCustomerInfo(result.customerInfo);
  } on PlatformException catch (e) {
    ...
  }
}
```

Thay bằng:
```dart
@override
Future<SubscriptionStatus> purchase(SubscriptionPackage package) async {
  try {
    final nativePkg = package.nativePackage as Package;
    final result = await Purchases.purchase(
      PurchaseParams.package(nativePkg),
    );

    // Extract purchase token from RC SDK transaction (Android only).
    // transactionIdentifier = purchase token on Android, used to validate with Google Play API.
    final purchaseToken = result.transaction?.transactionIdentifier;
    final productId = package.identifier;
    if (purchaseToken != null && purchaseToken.isNotEmpty) {
      await _verifyWithGooglePlay(purchaseToken, productId);
    } else {
      Log.w('[RC] No purchase token in transaction — skipping Google Play verify');
    }

    return _mapCustomerInfo(result.customerInfo);
  } on PlatformException catch (e) {
    Log.e('[RC] purchase error code=${e.code} message=${e.message}');
    if (e.code == '1') {
      throw const AppException.payment(
        message: 'Purchase cancelled',
        code: 'user_cancelled',
      );
    }
    if (e.code == '28') {
      Log.w('[RC] ITEM_ALREADY_OWNED — fetching current CustomerInfo');
      return getStatus();
    }
    throw AppException.payment(
      message: e.message ?? 'Purchase failed',
      code: e.code,
    );
  }
}

/// Validate purchase with Google Play Publisher API via Supabase edge function.
/// Non-blocking: errors logged but do NOT throw (don't break purchase flow).
Future<void> _verifyWithGooglePlay(String purchaseToken, String productId) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'verify-google-purchase',
      body: {'purchaseToken': purchaseToken, 'productId': productId},
    );
    final body = response.data as Map<String, dynamic>?;
    if (body?['verified'] == true) {
      Log.i('[RC] GP verify OK: tier=${body?['tier']}, credits=${body?['credits']}');
    } else {
      Log.w('[RC] GP verify skipped: ${body?['reason']}');
    }
  } on Object catch (e) {
    Log.w('[RC] verify-google-purchase failed (non-blocking): $e');
  }
}
```

**Note:** Cần thêm import:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

### Step 3: Analyze

```bash
flutter analyze lib/features/subscription/data/repositories/subscription_repository.dart
```
Expected: `No issues found!`

### Step 4: Commit

```bash
git add lib/features/subscription/data/repositories/subscription_repository.dart
git commit -m "feat(subscription): call verify-google-purchase after RC purchase to sync Supabase"
```

---

## Task 3: Deploy + Test End-to-End

**Không có code thay đổi — verify deployment và test.**

### Step 1: Verify edge function deployed

```bash
supabase functions list --project-ref kytbmplsazsiwndppoji | grep verify
```
Expected: `verify-google-purchase` listed

### Step 2: Verify GOOGLE_PLAY_SERVICE_ACCOUNT_JSON secret set

```bash
supabase secrets list --project-ref kytbmplsazsiwndppoji | grep GOOGLE_PLAY
```
Expected: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON | <digest>`

### Step 3: Build AAB mới

```bash
flutter build appbundle --dart-define=ENV=production --release
```
Expected: `Built build/app/outputs/bundle/release/app-release.aab`

### Step 4: Upload lên Play Console Internal Testing

Upload AAB lên: Play Console → Internal Testing → bump version nếu cần

### Step 5: Test với email mới

Dùng email chưa từng mua. Sau khi purchase:
- ✅ App hiện "Pro/Ultra plan premium"
- ✅ RC Dashboard: có customer mới (nếu RC đã fix)
- ✅ Supabase `is_premium=true` — **không cần RC webhook**
- ✅ Credit balance tăng 200/500

### Step 6: Verify Supabase

```bash
SERVICE_KEY="<SUPABASE_SERVICE_ROLE_KEY>"
curl "https://kytbmplsazsiwndppoji.supabase.co/rest/v1/profiles?select=email,is_premium,subscription_tier&order=updated_at.desc&limit=3" \
  -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY"

curl "https://kytbmplsazsiwndppoji.supabase.co/rest/v1/credit_transactions?select=*&order=created_at.desc&limit=3" \
  -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY"
```
Expected: `is_premium: true`, credit_transaction với `reference_id: "gp-GPA.xxxx"` (orderId format)

### Step 7: Analyze + test suite

```bash
flutter analyze
flutter test --exclude-tags=integration
```
Expected: No issues, all tests pass.

### Step 8: Commit + push

```bash
git push origin fix/credit-exhausted-no-upgrade-option
```

---

## Checklist

- [ ] GCP: Service account `artio-play-validator` tạo xong + JSON key downloaded
- [ ] Play Console: Service account granted "View financial data" + "Manage orders"
- [ ] Supabase secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` set
- [ ] Edge function `verify-google-purchase` deployed
- [ ] `subscription_repository.dart` gọi edge function sau purchase
- [ ] Build AAB mới + upload Internal Testing
- [ ] E2E test: purchase → Supabase tự update (không manual)
- [ ] Credit_transactions có entry với `reference_id: "gp-GPA.xxx"`
- [ ] `flutter analyze`: No issues
- [ ] `flutter test`: All pass
