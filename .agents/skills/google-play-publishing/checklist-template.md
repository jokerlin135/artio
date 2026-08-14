# Google Play Publishing — Detection Checklist

Run this interview for any new app before Play Console submission.
Cross-reference answers with `data-types-matrix.md` to generate declarations.

---

## 🔍 10-Question App Interview

### Q1 — Authentication method?
- [ ] No login (guest only)
- [ ] Email + password
- [ ] Email + OTP / magic link
- [ ] Google Sign-In (OAuth)
- [ ] Apple Sign-In (OAuth)
- [ ] Phone number / SMS OTP
- [ ] Anonymous auth

→ **Determines:** Email address, Phone number, User IDs, Account creation method

---

### Q2 — Which SDKs does the app use?
*(Scan `pubspec.yaml` or `package.json` for these)*

**Ads:**
- [ ] `google_mobile_ads` / AdMob
- [ ] `facebook_audience_network`
- [ ] AppLovin MAX
- [ ] ironSource

**Analytics / Crash:**
- [ ] `sentry_flutter`
- [ ] `firebase_analytics`
- [ ] `firebase_crashlytics`
- [ ] `mixpanel_flutter`

**Monetization:**
- [ ] `purchases_flutter` (RevenueCat)
- [ ] `in_app_purchase` (native)
- [ ] Adapty

**Attribution:**
- [ ] `adjust_sdk`
- [ ] `appsflyer_sdk`

**Push:**
- [ ] `onesignal_flutter`
- [ ] `firebase_messaging`

→ **Determines:** Most data type declarations automatically

---

### Q3 — Does the app use camera or file picker?
- [ ] Yes, camera for photos/video → **Photos, Videos (ephemeral)**
- [ ] Yes, image_picker to upload → **Photos (ephemeral)**
- [ ] No

---

### Q4 — Does the app access location?
- [ ] Precise GPS (delivery, navigation, "find near me") → **Precise location**
- [ ] Approximate (city-level, "content near you") → **Approximate location**
- [ ] No location features → ❌

---

### Q5 — Does the app generate or display server-side content?
- [ ] AI-generated images/text → **Online content = YES** in Content Ratings
- [ ] Social feed (posts from other users) → **Online content = YES, User content sharing = YES**
- [ ] Chat / messaging → **Online content = YES**
- [ ] Static app only (no server content) → Online content = No

> ⚠️ This is the most commonly misconfigured field. When in doubt → YES.

---

### Q6 — What is the target audience?
- [ ] All ages, no sensitive content → 13+
- [ ] Social features with user content → 13+ (verify)
- [ ] AI content generation (no strict NSFW filter) → **18+**
- [ ] Dating, alcohol, gambling themes → **18+**
- [ ] Children's app → Under 13 (special COPPA rules apply)

---

### Q7 — Does the app have in-app purchases?
- [ ] Yes → **Purchase digital goods = Yes** in Content Ratings
- [ ] Yes, with random/loot box mechanics → **Random items = Yes**
- [ ] No

---

### Q8 — Does the app require login to use core features?
- [ ] Yes → App Access = "All or some functionality is restricted"
  → Provide: test email + password for Google reviewer
- [ ] No (full guest mode) → App Access = "All functionality available"
- [ ] Partial (some features require login) → "All or some restricted"

---

### Q9 — Does the app collect contacts, calendar, or health data?
- [ ] Import contacts / autofill from contacts → **Contacts**
- [ ] Calendar integration / reminders → **Calendar events**
- [ ] Health metrics / fitness tracking → **Health info / Fitness info**
- [ ] None of the above → ❌

---

### Q10 — Does app have a Delete Account feature?
- [ ] App has NO user accounts → Skip (no deletion URL needed)
- [ ] Yes, in-app (direct deletion) → Provide URL of web page explaining steps + data deleted
- [ ] Yes, via email request → Provide web page or email address as URL
- [ ] No feature yet → ❌ Must create one before submission (required if app has accounts)

---

## 📊 Output Template

After answering above, fill this table:

```
App name: ___________
Package: ___________
Auth: ___________
SDKs: ___________

=== PLAY CONSOLE DECLARATIONS ===

Countries: All / [List exceptions]
App access: All available / Restricted → Test credentials: [email] / [password]
Ads: Yes / No
Content ratings:
  - Online content: Yes / No
  - User content sharing: Yes / No
  - Purchase digital goods: Yes / No
  - Random purchases: Yes / No
Target audience: [age range]
Delete account URL: [URL]

Data Safety:
  Collects data: Yes
  Encrypted in transit: Yes
  Account creation: [methods]
  Data types:
    [checkbox list from matrix]

Advertising ID: Yes / No
  Purposes: Advertising or marketing / Analytics

Store Settings:
  Category: [Photography / Tools / Art & Design / ...]
  Contact email: [email]
  Website: [privacy policy or landing page URL]
  External marketing: On / Off
```
