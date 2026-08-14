# SDK → Data Types Matrix

Use this matrix to determine which Data Safety data types to declare based on SDKs and features in the app.

---

## SDK Detection Matrix

| SDK / Package | Data Type | Collected | Shared | Purpose |
|---------------|-----------|-----------|--------|---------|
| `supabase_flutter` | Email address | ✅ | ❌ | App functionality, Account management |
| `supabase_flutter` | User IDs | ✅ | ✅ (if using RevenueCat/Sentry) | App functionality, Account management |
| `firebase_auth` | Email address | ✅ | ❌ | App functionality, Account management |
| `firebase_auth` | User IDs | ✅ | ✅ (Firebase) | App functionality |
| `google_mobile_ads` | Device or other IDs | ✅ | ✅ (Google) | Advertising or marketing |
| `google_mobile_ads` | App interactions | ✅ | ❌ | Analytics |
| `firebase_analytics` | App interactions | ✅ | ✅ (Firebase) | Analytics |
| `firebase_analytics` | Device or other IDs | ✅ | ✅ (Firebase) | Analytics |
| `purchases_flutter` (RevenueCat) | Purchase history | ✅ | ❌ | App functionality, Account management |
| `purchases_flutter` (RevenueCat) | User IDs | ✅ | ✅ (RevenueCat) | App functionality |
| `sentry_flutter` | Crash logs | ✅ | ❌ | Analytics |
| `sentry_flutter` | Diagnostics | ✅ | ❌ | Analytics |
| `sentry_flutter` | User IDs | ✅ | ✅ (Sentry) | Analytics |
| `image_picker` | Photos | ✅ (ephemeral) | ❌ | App functionality |
| `camera` | Photos | ✅ (ephemeral) | ❌ | App functionality |
| `file_picker` | Files / Videos | ✅ (ephemeral) | ❌ | App functionality |
| `video_player` | (no data — playback only) | — | — | — |
| `geolocator` / `location` | Approximate location | ✅ | ❌ | App functionality |
| `geolocator` (precise) | Precise location | ✅ | ❌ | App functionality |
| `contacts_service` / `flutter_contacts` | Contacts | ✅ | ❌ | App functionality |
| `flutter_local_notifications` | (no data) | — | — | — |
| `mixpanel_flutter` | App interactions | ✅ | ✅ (Mixpanel) | Analytics |
| `adjust_sdk` | Device or other IDs | ✅ | ✅ (Adjust) | Advertising or marketing |
| `appsflyer_sdk` | Device or other IDs | ✅ | ✅ (AppsFlyer) | Advertising or marketing |
| `onesignal_flutter` | Device or other IDs | ✅ | ✅ (OneSignal) | Developer communications |
| `app_tracking_transparency` | (no data — iOS permission only) | — | — | Controls whether AdMob uses Advertising ID on iOS |

---

## Feature Detection Matrix

| App Feature | Data Type | Collected | Shared | Notes |
|-------------|-----------|-----------|--------|-------|
| Email/password login | Email address, User IDs | ✅ | ❌ | Always required |
| Google Sign-In / OAuth | User IDs | ✅ | ✅ | Shared with OAuth provider |
| Phone auth | Phone number | ✅ | ❌ | — |
| IAP / Subscriptions | Purchase history | ✅ | ❌ | — |
| AI image generation (server) | Other user-generated content | ✅ | ❌ | Stored on server |
| Upload photo input for AI | Photos | ✅ | ❌ | Ephemeral = Yes |
| In-app chat / messaging | Other in-app messages | ✅ | ❌ | — |
| Public profile with name | Name | ✅ | ✅ | Shared with other users |
| Map / navigation feature | Precise location | ✅ | ❌ | — |
| Delivery / nearby search | Approximate location | ✅ | ❌ | — |
| Contact import | Contacts | ✅ | ❌ | — |
| Audio recording | Voice or sound recordings | ✅ | ❌ | — |
| Health tracking | Health info | ✅ | ❌ | — |
| Fitness tracking | Fitness info | ✅ | ❌ | — |

---

## Ephemeral vs Stored

| Data | Ephemeral? | Rationale |
|------|-----------|-----------|
| Photos uploaded for AI processing | ✅ Yes | Processed in memory, not stored |
| Photos saved to gallery/server | ❌ No | Permanently stored |
| Crash logs | ❌ No | Retained by Sentry |
| Auth tokens | ✅ Yes | In-memory session |
| User profile email | ❌ No | Stored in DB |

---

## Required vs Optional

| Data type | Required? | Rationale |
|-----------|-----------|-----------|
| Email address | **Required** | No email = no account |
| User IDs | **Required** | Core to auth |
| Purchase history | **Required** | IAP flow depends on it |
| Photos | **Users can choose** | Feature is optional |
| Precise location | **Users can choose** | Permission-gated |
| Crash logs | **Required** | Always-on Sentry |
| Device or other IDs (AdMob) | **Required** | AdMob always active |
