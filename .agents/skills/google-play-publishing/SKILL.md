---
name: google-play-publishing
description: Use when preparing a Google Play Store submission, filling Data Safety declarations, Content Ratings, Target Audience, App Access, Advertising ID, or any Play Console policy form. Use when blocked on what to declare for specific SDKs (AdMob, Firebase, RevenueCat) or confused by rejection warnings.
---

## When to Use

User is preparing a Google Play Store submission, setting up Data Safety declarations, filling in Content Ratings, or needs guidance on any Play Console policy form.

## Quick Reference

| Topic | File |
|-------|------|
| SDK → Data type matrix | `data-types-matrix.md` |
| Interview checklist | `checklist-template.md` |
| Real app example (Artio) | `examples/artio-ai-photo.md` |

## Agent Protocol

**Step 1 — Run the interview (from `checklist-template.md`):**
Ask the user the 10 detection questions OR scan `pubspec.yaml` / `package.json` automatically.

**Step 2 — Map to declarations (from `data-types-matrix.md`):**
Cross-reference SDKs + features against the matrix to determine every data type.

**Step 3 — Output the complete form:**
Generate a ready-to-fill declaration table for each Play Console section.

---

## Section Rules

### 1. Countries / Regions
- Default: **All countries** for most apps
- Exceptions: Apps with OFAC-restricted content (crypto, gambling in prohibited regions)
- Google automatically blocks OFAC-sanctioned countries (Iran, North Korea, Cuba, Syria)

### 2. App Access
| Scenario | Selection |
|----------|-----------|
| No login required (full guest) | All functionality available without restrictions |
| Login required for ALL core features | All or some functionality is restricted → provide test credentials |
| Partial guest (some features need login) | All or some functionality is restricted → note which features require login |

### 3. Ads
- Any AdMob / AdColony / AppLovin / ironSource dependency → **Yes, app contains ads**

### 4. Content Ratings — Critical Rules
| Question | Rule |
|----------|------|
| Online content | **YES** if app pulls ANY server content (AI generation, feeds, chat, marketplace) |
| User content sharing | YES if users see content created by other users |
| Random/loot box purchases | YES if IAP outcome is randomized |
| Purchase digital goods | YES if any IAP exists |

> ⚠️ **"Online content = No" is the #1 rejection cause for apps with server-side content.**

### 5. Target Audience
| App type | Safe minimum age |
|----------|-----------------|
| General utility, no UGC | 13+ |
| Social/chat features | 13+ with content policy |
| AI-generated content (no NSFW filter) | **18+** |
| AI-generated content (strict NSFW filter) | 13+ (verify with legal) |
| Dating, alcohol, gambling themes | 18+ |

### 6. Data Safety — Account Deletion URL
Google requires a public URL that:
1. Explains how to delete account
2. Lists what data is deleted
3. States retention period

Options (in preference order):
1. In-app deletion flow + Web page URL (`privacy.html#account-deletion`)
2. Email request process with response SLA
3. Google Form / Typeform (minimum viable)

### 7. Advertising ID
- Any AdMob / Firebase Analytics / Adjust / AppsFlyer → **must declare AD_ID usage**
- Required checkbox: **Advertising or marketing** + **Analytics**
- AD_ID permission auto-merges from SDK manifests — always declare even if not explicit in your manifest

### 8. Store Settings
| Field | Rule |
|-------|------|
| Category | Most specific category available |
| Email | Support/developer contact email |
| Website | At minimum a privacy policy URL |
| External marketing | Keep ON unless legal requires off |

### 9. Privacy Policy
Google Play **requires** a publicly accessible Privacy Policy URL for any app that:
- Has user accounts
- Collects personal data
- Contains ads

> Almost every production app needs one. Use `privacy.html` on GitHub Pages as minimum viable option.

Policy must:
1. Identify data collected and why
2. Name all third-party SDKs that receive data
3. Explain data retention and deletion process
4. Provide a contact email

---

## Common Mistakes

- ❌ Online Content = No → **instant rejection** for server-content apps
- ❌ Not declaring AD_ID when using AdMob → policy violation
- ❌ Empty delete account URL → Play Console blocks submission
- ❌ Choosing "Users can choose" for auth data → auth data is always required
- ❌ Marking Photos as "Not ephemeral" when app only processes them temporarily
- ❌ Forgetting RevenueCat shares User IDs → User IDs = Collected + Shared
