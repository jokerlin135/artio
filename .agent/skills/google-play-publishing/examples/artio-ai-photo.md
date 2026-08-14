# Example: Artio — AI Photo Generation App

Completed Play Console declaration for Artio v1.0.0+18 (March 2026 Open Testing release).
Use as reference template for similar AI apps.

---

## App Profile

| Field | Value |
|-------|-------|
| App name | Artio — AI Photo Generator |
| Package | `com.ainear.artio` |
| Version | 1.0.0+18 |
| Platform | Flutter (Android + iOS) |
| Auth | Supabase (email/password + OTP) |
| Track | Open Testing → Production |

## SDKs

```yaml
supabase_flutter: ^2.x        # Auth + DB + Storage
google_mobile_ads: ^5.x       # AdMob ads
purchases_flutter: ^7.x       # RevenueCat IAP
sentry_flutter: ^8.x          # Crash reporting
image_picker: ^1.x            # Photo upload input
package_info_plus: ^8.x       # Version info
```

---

## ✅ Complete Declaration

### Countries / Regions
**All countries** — AI photo app, no geographic restrictions.

### App Access
**"All or some functionality is restricted"**
- Login required to generate images and view gallery
- Test credentials provided to Google reviewer

### Ads
**Yes** — uses Google AdMob (`google_mobile_ads`)

### Content Ratings
| Question | Answer | Reason |
|----------|--------|--------|
| Downloaded content (bundled) | No | Content generated on server |
| **Online content** | **Yes** ✅ | AI images fetched from server |
| User content sharing | No | Gallery is private per user |
| Age-restricted products | No | No alcohol/tobacco/gambling |
| Share precise location | No | No location features |
| Purchase digital goods | Yes | RevenueCat subscriptions + credits |
| Random/loot box | No | Deterministic purchases |
| Cash rewards / NFTs | No | — |
| Web browser | No | — |

→ **Result:** ESRB Teen (13+) but selected **18+ for Target Audience** due to unfiltered AI content

### Target Audience
**18 and over** — AI generation without guaranteed NSFW filtering.

### Account Deletion URL
```
https://ainear.github.io/artio-legal/privacy.html#account-deletion
```
- In-app deletion: Settings → Account → Delete Account (immediate)
- Email fallback: toiyeuhvhc123@gmail.com

### Data Safety — Data Collection & Security

| Question | Answer |
|----------|--------|
| Collects data | Yes |
| Encrypted in transit | Yes (Supabase HTTPS) |
| Account creation | Username and other authentication (email + OTP) |
| Delete account URL | `...privacy.html#account-deletion` |
| Partial data deletion | No |

### Data Safety — Data Types

| Data type | Collected | Shared | Ephemeral | Required | Purpose |
|-----------|-----------|--------|-----------|----------|---------|
| Email address | ✅ | ❌ | No | Required | App functionality, Account management |
| User IDs | ✅ | ✅ | No | Required | App functionality, Account management |
| Purchase history | ✅ | ❌ | No | Required | App functionality, Account management |
| Photos | ✅ | ❌ | **Yes** | Optional | App functionality (AI input, not stored) |
| App interactions | ✅ | ❌ | No | Required | Analytics (AdMob) |
| Other user-generated content | ✅ | ❌ | No | Required | App functionality (AI images stored in gallery — declared as app-generated content) |
| Crash logs | ✅ | ❌ | No | Required | Analytics (Sentry) |
| Diagnostics | ✅ | ❌ | No | Required | Analytics (Sentry) |
| Device or other IDs | ✅ | ✅ | No | Required | Advertising or marketing (AdMob AD_ID) |

#### Shared With:
- **User IDs** → RevenueCat (subscription mgmt), Sentry (crash context)
- **Device or other IDs** → Google AdMob

### Advertising ID
**Yes** — uses `google_mobile_ads` which auto-merges `AD_ID` permission.

Purposes:
- ☑️ Advertising or marketing (show ads)
- ☑️ Analytics (measure ad performance)

### Store Settings
| Field | Value |
|-------|-------|
| Category | Photography |
| Contact email | toiyeuhvhc123@gmail.com |
| Website | https://ainear.github.io/artio-legal/ |
| External marketing | ✅ Enabled |

---

## ⚠️ Artio-Specific Notes

1. **Photos are ephemeral** — `image_picker` only hands the file to AI API, raw file is not stored server-side. ✅ Mark as ephemeral.
2. **User IDs are shared** — RevenueCat receives the Supabase UUID to link subscription status. Declare `User IDs → Shared → App functionality`.
3. **Online Content = Yes** — most critical flag for AI apps. Server generates images → must be Yes.
4. **No location, contacts, calendar, audio, health** — none of these SDKs present.
5. **"Other user-generated content" caveat** — Play Console uses this category for both UGC (user-created) and app-generated content stored per user (AI images). Despite the misleading name, declaring AI gallery images here is correct per Google’s examples.
