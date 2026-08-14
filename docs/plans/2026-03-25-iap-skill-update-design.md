# IAP Skill Surgical Update — Design Doc

**Date:** 2026-03-25
**File:** `.agent/skills/iap-revenuecat/SKILL.md`
**Trigger:** PR #83 + PR #84 introduced 5 divergences from skill documentation

## Decision: Surgical Fix (Option A)

YAGNI — 5 divergences are confirmed with exact locations. Full rewrite would be scope creep on a 1000+ line production-critical file.

## Changes In Scope

### C1 — Remove `rc-` fallback from `isValidPurchaseToken` (lines 575–578)

The `rc-{productId}-{unixMs}` fallback pattern was **removed from production** in PR #83 because any authenticated user could forge timestamp-based tokens to repeatedly claim credits.

**Remove:**
```typescript
// App fallback when orderId is empty (free trial subscriptions):
// rc-{productId}-{unixMs}
if (/^rc-appname_(ultra|pro)_[a-z]+-\d{10,13}$/.test(token)) return true;
```

**Update doc comment** to reflect GPA-only policy.

### C2 — Add `handleCorsIfPreflight` + `corsHeaders` to `verify-google-purchase` (line 581)

Production now handles OPTIONS preflight and returns CORS headers on all responses.

**Add at top of Deno.serve:**
```typescript
import { corsHeaders, handleCorsIfPreflight } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsIfPreflight(req);
  if (preflight) return preflight;
  // ...
  return new Response(JSON.stringify({...}), {
    status: 200,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
});
```

### C3 — Remove `update_subscription_status` from `verify-google-purchase` (lines 590–596)

Production intentionally removed this call. `productId` is client-supplied — setting tier from it before RC webhook verification allows tier escalation (user claims ultra with a pro token).

**Remove the RPC call + add security note:**
```typescript
// NOTE: update_subscription_status intentionally omitted.
// productId is client-supplied → setting tier here allows tier escalation.
// RC webhook fires within seconds and sets the authoritative tier + expiry.
```

**Update migration path note (line 609):** The note now says "remove grant_subscription_credits, keep update_subscription_status" — but update_subscription_status is already removed. Update to reflect current state.

### C4 — Add `p_check_recent_grant: true` to `grant_subscription_credits` (lines 600–605)

Production uses this flag to run the 25-day guard inside the RPC under `pg_advisory_xact_lock`, preventing TOCTOU race with the RC webhook.

**Update call:**
```typescript
await supabase.rpc("grant_subscription_credits", {
  p_user_id: user.id,
  p_amount: tierInfo.credits,
  p_description: `${tierInfo.tier} subscription — Google Play purchase`,
  p_reference_id: referenceId,
  p_check_recent_grant: true,  // ← 25-day guard inside RPC, atomic with advisory lock
});
```

### C5 — Fix `revenuecat-webhook` auth example (line 618)

Current code shows:
```typescript
const expectedAuth = `Bearer ${REVENUECAT_WEBHOOK_SECRET}`;
```

This **contradicts Gotcha #6** (RC sends raw token, no Bearer prefix). Fix to:
```typescript
const expectedAuth = REVENUECAT_WEBHOOK_SECRET;  // raw token — RC sends no Bearer prefix (Gotcha #6)
```

Also update comment on line 616 — `timingSafeEqual` IS available (Gotcha #11 already documents this but code comment still says "not in Supabase runtime").

### C6 — Add Gotcha #19 (after Gotcha #18, before section 10)

New gotcha: unexpected `grantResult` shape must return HTTP 500, not fall through to 200.

**Insert after line 392 (end of Gotcha #18):**
```markdown
### 19. 🆕 Unexpected `grantResult` Shape Must Return 500, Not Fall Through

**Problem:** If `grant_subscription_credits` RPC returns an unrecognized shape
(neither `{granted: true}` nor `{granted: false, reason: "..."}`) and the code
falls through to return 200, RevenueCat sees success and stops retrying.
The user gets no credits and no retry mechanism fires.

**Wrong:**
```typescript
} else {
  console.warn("Unexpected grantResult:", grantResult);
  // falls through to 200 response — RC thinks it succeeded
}
```

**Fix — return 500 so RC retries:**
```typescript
} else {
  console.error("[verify-google-purchase] Unexpected grantResult shape:", JSON.stringify(grantResult));
  return new Response(
    JSON.stringify({ error: "Internal error: unexpected grant result" }),
    { status: 500, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
  );
}
```

RevenueCat retries on 5xx (not 4xx). A 500 here surfaces the bug via retries + ops logs.
```

### Metadata Update

- Lines 7–10: Add `verify-google-purchase CORS preflight, rc- token removal, p_check_recent_grant, Gotcha #19.`
- Line 18: Update `Last Updated` to `2026-03-25`

## Out of Scope

- Full audit of other sections
- iOS-specific patterns
- Flutter client code examples
- Database migration docs
