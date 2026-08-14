# IAP Skill Surgical Update — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Sync `.agent/skills/iap-revenuecat/SKILL.md` with production code changes from PR #83 + PR #84 — 6 surgical edits.

**Architecture:** Pure documentation update. No code changes, no tests to run. Verification = diff review + logical correctness check after each edit. All edits to a single file.

**Tech Stack:** Markdown, git

---

## Task 1: C1 — Remove `rc-` fallback from `isValidPurchaseToken`

**Files:**
- Modify: `.agent/skills/iap-revenuecat/SKILL.md` (lines 568–579)

**Context:**
The `rc-{productId}-{unixMs}` fallback token was removed from production because any authenticated user could forge timestamp-based tokens to claim credits repeatedly. Only GPA tokens are now accepted.

**Step 1: Read the exact current text**

Read lines 568–579 of `.agent/skills/iap-revenuecat/SKILL.md` to confirm:
```typescript
/**
 * 🔒 SECURITY: Validate purchaseToken format to block fake/exploited grants.
 * Accepts real Google Play order IDs AND app-generated fallback tokens only.
 */
function isValidPurchaseToken(token: string): boolean {
  // Real Google Play order ID: GPA.XXXX-XXXX-XXXX-XXXXX
  if (/^GPA\.\d{4}-\d{4}-\d{4}-\d+$/.test(token)) return true;
  // App fallback when orderId is empty (free trial subscriptions):
  // rc-{productId}-{unixMs}
  if (/^rc-appname_(ultra|pro)_[a-z]+-\d{10,13}$/.test(token)) return true;
  return false;
}
```

**Step 2: Replace with updated version**

Replace the entire block with:
```typescript
/**
 * 🔒 SECURITY: Validate purchaseToken format to block fake/exploited grants.
 * Accepts ONLY real Google Play order IDs (GPA.XXXX-XXXX-XXXX-XXXXX).
 * ⚠️ Do NOT add timestamp-based fallbacks (rc-...) — any authenticated user
 * can forge them with arbitrary timestamps to repeatedly claim credits.
 */
function isValidPurchaseToken(token: string): boolean {
  // Real Google Play order ID: GPA.XXXX-XXXX-XXXX-XXXXX
  return /^GPA\.\d{4}-\d{4}-\d{4}-\d+$/.test(token);
}
```

**Step 3: Verify diff**
```bash
git diff .agent/skills/iap-revenuecat/SKILL.md
```
Expected: Only lines 568–579 changed. `rc-` pattern gone. Doc comment updated to "GPA-only".

**Step 4: Commit**
```bash
git add .agent/skills/iap-revenuecat/SKILL.md
git commit -m "docs(skill): remove rc- fallback token from isValidPurchaseToken — security fix"
```

---

## Task 2: C2 + C3 + C4 — Update `verify-google-purchase` code example

**Files:**
- Modify: `.agent/skills/iap-revenuecat/SKILL.md` (lines 554–609)

**Context:**
Three changes to the `verify-google-purchase` code block:
- **C2**: Add `handleCorsIfPreflight` + `corsHeaders()` (PR #84 CRITICAL fix)
- **C3**: Remove `update_subscription_status` call (security — tier escalation risk), update migration path note
- **C4**: Add `p_check_recent_grant: true` to prevent double-grant race condition

**Step 1: Read the full current section (lines 554–609)**

Confirm the current code block matches what was analyzed.

**Step 2: Replace the entire section 5.1 code block + migration note**

Find the text starting at `#### 5.1 verify-google-purchase (immediate fallback)` through the migration path note.

Replace with:

```markdown
#### 5.1 verify-google-purchase (immediate fallback)
Called by app right after `Purchases.purchase()` succeeds. Grants credits immediately without waiting for RC webhook.

```typescript
// supabase/functions/verify-google-purchase/index.ts
// Deploy: supabase functions deploy verify-google-purchase --no-verify-jwt
import { corsHeaders, handleCorsIfPreflight } from "../_shared/cors.ts";

/** Map product ID → tier + credits */
function getTierInfo(productId: string): { tier: string; credits: number } | null {
  if (productId.startsWith("appname_ultra_")) return { tier: "ultra", credits: 500 };
  if (productId.startsWith("appname_pro_"))  return { tier: "pro",   credits: 200 };
  return null;
}

/**
 * 🔒 SECURITY: Accepts ONLY real Google Play order IDs (GPA.XXXX-XXXX-XXXX-XXXXX).
 * Do NOT add timestamp-based fallbacks — forgeable by any authenticated user.
 */
function isValidPurchaseToken(token: string): boolean {
  return /^GPA\.\d{4}-\d{4}-\d{4}-\d+$/.test(token);
}

Deno.serve(async (req) => {
  // Handle CORS preflight before anything else
  const preflight = handleCorsIfPreflight(req);
  if (preflight) return preflight;

  // ... auth check (see Gotcha #8) ...

  // Validate token format BEFORE any DB writes
  if (!isValidPurchaseToken(purchaseToken)) {
    console.warn(`[verify-google-purchase] Invalid token: "${purchaseToken}" user=${user.id}`);
    return new Response(JSON.stringify({ error: "Invalid purchaseToken format" }), {
      status: 400,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }

  // NOTE: update_subscription_status intentionally omitted.
  // productId is client-supplied → setting tier here before RC webhook verification
  // allows tier escalation (user claims ultra credits with a pro token).
  // The RC webhook fires within seconds and sets the authoritative tier + expiry.

  // Grant credits — idempotent via reference_id.
  // p_check_recent_grant=true runs the 25-day guard inside the RPC under
  // pg_advisory_xact_lock — eliminates TOCTOU race with revenuecat-webhook.
  const referenceId = `gp-${purchaseToken}`;
  const { data: grantResult, error: creditErr } = await supabase.rpc("grant_subscription_credits", {
    p_user_id: user.id,
    p_amount: tierInfo.credits,
    p_description: `${tierInfo.tier} subscription — Google Play purchase`,
    p_reference_id: referenceId,
    p_check_recent_grant: true,
  });

  if (creditErr) {
    console.error("[verify-google-purchase] grant_subscription_credits error:", creditErr);
    return new Response(JSON.stringify({ error: "Failed to grant subscription credits" }), {
      status: 500,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }

  // Handle grantResult shapes (see Gotcha #19 for unexpected shape handling)
  // ...

  return new Response(JSON.stringify({ verified: true, tier: tierInfo.tier }), {
    status: 200,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
});
```

**Current state:** `update_subscription_status` has been removed. `grant_subscription_credits` now uses `p_check_recent_grant: true` for atomic double-grant prevention. When RC webhook is confirmed stable, `grant_subscription_credits` can also be removed — leaving this function as a no-op fast-path that just validates the token format.
```

**Step 3: Verify diff**
```bash
git diff .agent/skills/iap-revenuecat/SKILL.md
```
Expected:
- `handleCorsIfPreflight` import added ✅
- `handleCorsIfPreflight(req)` guard at top of handler ✅
- `corsHeaders()` on error responses ✅
- `update_subscription_status` block removed ✅
- `p_check_recent_grant: true` added ✅
- Migration path note updated ✅

**Step 4: Commit**
```bash
git add .agent/skills/iap-revenuecat/SKILL.md
git commit -m "docs(skill): update verify-google-purchase example — CORS, no tier-update, p_check_recent_grant"
```

---

## Task 3: C5 — Fix `revenuecat-webhook` auth example

**Files:**
- Modify: `.agent/skills/iap-revenuecat/SKILL.md` (lines 616–625)

**Context:**
Line 618 shows `const expectedAuth = \`Bearer \${REVENUECAT_WEBHOOK_SECRET}\`` — this contradicts **Gotcha #6** which clearly states RC sends raw token with NO Bearer prefix. Also line 616 comment says `timingSafeEqual not in Supabase runtime` but **Gotcha #11** confirms it IS available with a type cast.

**Step 1: Find the exact text (lines 616–625)**

```typescript
// Verify RC webhook signature (manual constant-time XOR — timingSafeEqual not in Supabase runtime)
const authHeader = req.headers.get("Authorization");
const expectedAuth = `Bearer ${REVENUECAT_WEBHOOK_SECRET}`;
const encoder = new TextEncoder();
const a = encoder.encode(authHeader ?? "");
const b = encoder.encode(expectedAuth);
let diff = a.length ^ b.length;
const len = Math.min(a.length, b.length);
for (let i = 0; i < len; i++) diff |= a[i] ^ b[i];
const authValid = authHeader !== null && diff === 0;
```

**Step 2: Replace with corrected version**

```typescript
// Verify RC webhook signature using constant-time comparison (Gotcha #6 + #11)
// RC sends Authorization header = raw token, NO "Bearer " prefix
const authHeader = req.headers.get("Authorization");
const expectedAuth = REVENUECAT_WEBHOOK_SECRET;  // raw token — no Bearer prefix (Gotcha #6)
// timingSafeEqual IS available in Deno via type cast (Gotcha #11)
const encoder = new TextEncoder();
const authValid = authHeader !== null && (
  crypto.subtle as unknown as { timingSafeEqual(a: BufferSource, b: BufferSource): boolean }
).timingSafeEqual(encoder.encode(authHeader), encoder.encode(expectedAuth));
```

**Step 3: Verify diff**
```bash
git diff .agent/skills/iap-revenuecat/SKILL.md
```
Expected:
- `Bearer ${REVENUECAT_WEBHOOK_SECRET}` → `REVENUECAT_WEBHOOK_SECRET` ✅
- Comment updated: references Gotcha #6 and #11 ✅
- XOR loop replaced with `timingSafeEqual` ✅

**Step 4: Commit**
```bash
git add .agent/skills/iap-revenuecat/SKILL.md
git commit -m "docs(skill): fix revenuecat-webhook auth — raw token (no Bearer), use timingSafeEqual"
```

---

## Task 4: C6 — Add Gotcha #19

**Files:**
- Modify: `.agent/skills/iap-revenuecat/SKILL.md` (after line 392, before `### 10.`)

**Context:**
When `grant_subscription_credits` returns an unexpected shape (not `{granted: true}` or `{granted: false, reason: ...}`), the code must return HTTP 500 — not fall through to a 200 success response. RevenueCat retries on 5xx but marks 4xx/2xx as permanent. Fall-through to 200 silently loses credits with no retry.

**Step 1: Find insertion point**

Locate the text `---\n\n### 10. 🆕 RC Webhook Requires Pub/Sub` (around line 392–394).

**Step 2: Insert Gotcha #19 BEFORE `### 10.`**

Insert this block between the `---` and `### 10.`:

```markdown
### 19. 🆕 Unexpected `grantResult` Shape Must Return 500 — Never Fall Through to 200

> **Root cause confirmed in production (2026-03-17)**

**Problem:** `grant_subscription_credits` RPC occasionally returns an unrecognized shape
(neither `{granted: true}` nor `{granted: false, reason: "..."}`) due to schema changes
or edge cases. If the code falls through to return 200, RevenueCat sees success and stops
retrying. The user gets no credits and no automatic recovery.

**Wrong — silent credit loss:**
```typescript
} else {
  console.warn("[verify-google-purchase] Unexpected grantResult:", grantResult);
  // falls through to 200 response — RC thinks it succeeded, stops retrying
}
return new Response(JSON.stringify({ verified: true }), { status: 200 });
```

**Fix — return 500 so RC retries and ops are alerted:**
```typescript
} else {
  console.error(
    "[verify-google-purchase] Unexpected grantResult shape:",
    JSON.stringify(grantResult),
  );
  return new Response(
    JSON.stringify({ error: "Internal error: unexpected grant result" }),
    { status: 500, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
  );
}
```

**Why 500 (not 400 or 422):** RevenueCat retries on **5xx** responses (server error = transient).
4xx = permanent failure, no retry. Returning 500 here keeps the retry loop alive until ops can investigate.

**Debug:** Check Supabase Edge Function logs for `Unexpected grantResult shape:` entries.
If seen in production, inspect the RPC's return value — likely a DB migration added a new field
or changed the response structure.

---
```

**Step 3: Verify diff**
```bash
git diff .agent/skills/iap-revenuecat/SKILL.md
```
Expected: Gotcha #19 block inserted between Gotcha #18 closing `---` and `### 10.` ✅

**Step 4: Commit**
```bash
git add .agent/skills/iap-revenuecat/SKILL.md
git commit -m "docs(skill): add Gotcha #19 — unexpected grantResult must return 500 not 200"
```

---

## Task 5: Update metadata header

**Files:**
- Modify: `.agent/skills/iap-revenuecat/SKILL.md` (lines 7–10, 18)

**Step 1: Find exact current metadata lines**

Lines 7–10:
```
  Updated 2026-03-16 with production-verified fixes: JWT ES256/HS256 mismatch, GPA token validation,
  verify-google-purchase fallback pattern, RC webhook Pub/Sub setup, webhook secret mismatch (Gotcha #17).
  RC auth raw token (no Bearer prefix), event.id null sandbox fallback (Gotcha #18).
  Date.now() idempotency fix (Gotcha #18 example corrected).
```

Line 18:
```
> **Last Updated:** 2026-03-16 (Production-verified v16 internal testing — RC webhook working, 4 events Sent, 820 credits. Gotcha #18 added: event.id null sandbox. Auth format corrected: raw token no Bearer prefix.)
```

**Step 2: Update description lines 7–10**

Replace with:
```
  Updated 2026-03-16 with production-verified fixes: JWT ES256/HS256 mismatch, GPA token validation,
  verify-google-purchase fallback pattern, RC webhook Pub/Sub setup, webhook secret mismatch (Gotcha #17).
  RC auth raw token (no Bearer prefix), event.id null sandbox fallback (Gotcha #18).
  Updated 2026-03-25: CORS preflight guard, rc- token security removal, p_check_recent_grant,
  update_subscription_status removal from verify-google-purchase, webhook auth fix, Gotcha #19.
```

**Step 3: Update Last Updated line 18**

Replace with:
```
> **Last Updated:** 2026-03-25 (PR #83+#84 sync — CORS preflight, rc- token removed, p_check_recent_grant, webhook auth raw token fix, Gotcha #19 unexpected grantResult → 500.)
```

**Step 4: Verify diff**
```bash
git diff .agent/skills/iap-revenuecat/SKILL.md
```
Expected: Only metadata lines changed ✅

**Step 5: Commit**
```bash
git add .agent/skills/iap-revenuecat/SKILL.md
git commit -m "docs(skill): update iap-revenuecat metadata — Last Updated 2026-03-25"
```

---

## Execution Notes

- **No flutter test / flutter analyze** needed — this is documentation only.
- Each task is a surgical Edit to one file. Read before editing.
- If a line number has shifted due to previous edits, search by content (not line number).
- Verify each diff before committing — wrong edits to skill docs propagate silently.
- The `.worktrees/` copy of SKILL.md is outdated — only edit the main `.agent/skills/iap-revenuecat/SKILL.md`.
