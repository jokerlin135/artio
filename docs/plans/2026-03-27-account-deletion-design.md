# Account Deletion — Design Doc

**Date:** 2026-03-27
**Status:** Approved
**Required by:** Google Play Store (Dec 2023) + Apple App Store (June 2022)

## Problem

App allows account creation but has no account deletion feature. Both stores require apps that allow sign-up to also allow account deletion, including all associated user data. Missing this → guaranteed rejection.

## Approach: Edge Function (Approved)

Flutter calls `supabase.functions.invoke('delete-account')` with the user's JWT. The edge function validates the JWT, deletes all Storage files for the user, then calls `auth.admin.deleteUser(userId)` using the service role key. All DB tables cascade automatically via `ON DELETE CASCADE` foreign keys. RevenueCat and Riverpod state are cleaned up on the Flutter side after success.

Rejected alternatives:
- **PostgreSQL RPC**: Cannot delete Supabase Storage objects — leaves orphaned files.
- **Soft delete**: Does not satisfy store requirements (auth user must be deleted).

## Data Deleted

| Layer | How |
|-------|-----|
| `profiles` | `ON DELETE CASCADE` from `auth.users` |
| `user_credits` | `ON DELETE CASCADE` |
| `ad_views` | `ON DELETE CASCADE` |
| `generation_jobs` | `ON DELETE CASCADE` |
| `pending_ad_rewards` | `ON DELETE CASCADE` |
| `rate_limit` | `ON DELETE CASCADE` |
| Storage `generated-images/{userId}/` | Edge function explicit delete before auth user delete |
| RevenueCat identity | `Purchases.logOut()` on Flutter side |
| Riverpod providers | `invalidateUserScopedProviders(ref)` |

## Flow

```
Settings UI
  → _deleteAccount()
    → ConfirmationDialog (1 step: "Delete Account?" + warning)
      → authViewModel.deleteAccount()
        → authRepository.deleteAccount()
          → functions.invoke('delete-account')
            1. auth.getUser(jwt) → userId
            2. storage.list('generated-images/{userId}/')
            3. storage.remove(all files)
            4. auth.admin.deleteUser(userId)  ← cascades all DB
          ← 200 OK
        → Purchases.logOut()
        → invalidateUserScopedProviders(ref)
        → state = AuthState.unauthenticated()
        → router redirects → Login screen
```

## UI

- **Entry point:** Settings → Account section → "Delete Account" tile (red, destructive icon)
- **Confirmation dialog (1 step):**
  - Title: "Delete Account?"
  - Body: "This will permanently delete your account and all generated images. This cannot be undone."
  - Actions: "Cancel" (neutral) + "Delete" (red)
- **During deletion:** Full-screen loading overlay (reuse `LoadingStateWidget`)
- **On error:** SnackBar with error message, loading cleared

## Files Changed

| File | Change |
|------|--------|
| `supabase/functions/delete-account/index.ts` | New edge function |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | Add `deleteAccount()` |
| `lib/features/auth/data/repositories/auth_repository.dart` | Implement `deleteAccount()` |
| `lib/features/auth/presentation/view_models/auth_view_model.dart` | Add `deleteAccount()` |
| `lib/features/settings/presentation/settings_screen.dart` | Add `_deleteAccount()` + pass callback |
| `lib/features/settings/presentation/widgets/settings_sections.dart` | Add `onDeleteAccount` param + tile |

## Tests

- `AuthRepository.deleteAccount()` — mock `functions.invoke`: success path + error path
- `AuthViewModel.deleteAccount()` — verify state becomes `unauthenticated` on success, error preserved on failure
