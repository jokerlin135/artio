# Account Deletion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add "Delete Account" to Settings that permanently deletes the user's auth record, all DB rows (via CASCADE), all Storage images, and clears local state — satisfying Google Play and App Store requirements.

**Architecture:** A new Supabase Edge Function `delete-account` uses the service role key to: (1) delete all Storage objects under `generated-images/{userId}/`, (2) call `auth.admin.deleteUser(userId)` which cascades all DB tables. Flutter calls the function via `functions.invoke`, then clears RevenueCat identity and Riverpod state.

**Tech Stack:** Deno/TypeScript (edge function), Dart/Flutter, Riverpod codegen, mocktail, Supabase JS v2, `purchases_flutter`

---

### Task 1: Edge Function `delete-account`

**Files:**
- Create: `supabase/functions/delete-account/index.ts`

**Step 1: Create the edge function**

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const STORAGE_BUCKET = "generated-images";

function getSupabaseClient() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });
}

// Inlined from _shared/cors.ts (MCP deploy does not resolve cross-directory imports)
function corsHeaders(): Record<string, string> {
  const allowedOrigin =
    Deno.env.get("CORS_ALLOWED_ORIGIN") ?? "https://artio.app";
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function handleCorsIfPreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  return null;
}

Deno.serve(async (req) => {
  const preflight = handleCorsIfPreflight(req);
  if (preflight) return preflight;

  const headers = corsHeaders();

  try {
    // Validate JWT using service role client
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const supabase = getSupabaseClient();

    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        { status: 401, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    const userId = user.id;
    console.log(`[delete-account] Starting deletion for user=${userId}`);

    // Step 1: Delete all Storage objects for this user (paginated — handles >1000 files)
    const PAGE_SIZE = 1000;
    let offset = 0;
    let totalRemoved = 0;
    while (true) {
      const { data: storageFiles, error: listError } = await supabase.storage
        .from(STORAGE_BUCKET)
        .list(userId, { limit: PAGE_SIZE, offset });

      if (listError) {
        console.error(`[delete-account] Storage list error for user=${userId}:`, listError.message);
        break; // Non-fatal: proceed with account deletion even if storage cleanup fails
      }
      if (!storageFiles || storageFiles.length === 0) break;

      const paths = storageFiles.map((f) => `${userId}/${f.name}`);
      const { error: removeError } = await supabase.storage
        .from(STORAGE_BUCKET)
        .remove(paths);
      if (removeError) {
        console.error(`[delete-account] Storage remove error for user=${userId}:`, removeError.message);
        // Non-fatal: proceed with deletion
      } else {
        totalRemoved += paths.length;
      }
      if (storageFiles.length < PAGE_SIZE) break; // last page
      offset += PAGE_SIZE;
    }
    if (totalRemoved > 0) {
      console.log(`[delete-account] Removed ${totalRemoved} storage files for user=${userId}`);
    }

    // Step 2: Delete the auth user — cascades all DB tables
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error(`[delete-account] Auth delete error for user=${userId}:`, deleteError.message);
      return new Response(
        JSON.stringify({ error: "Failed to delete account" }),
        { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    console.log(`[delete-account] Successfully deleted user=${userId}`);
    return new Response(
      JSON.stringify({ ok: true }),
      { status: 200, headers: { ...headers, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("[delete-account] Unexpected error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
    );
  }
});
```

**Step 2: Verify file structure**

Run: `ls supabase/functions/delete-account/`
Expected: `index.ts`

**Step 3: Commit**

```bash
git add supabase/functions/delete-account/index.ts
git commit -m "feat(backend): add delete-account edge function

Deletes Storage objects under generated-images/{userId}/, then calls
auth.admin.deleteUser which cascades all DB tables via ON DELETE CASCADE.
Requires --no-verify-jwt (ES256/HS256 mismatch same as other functions)."
```

---

### Task 2: Domain — add `deleteAccount()` to interface

**Files:**
- Modify: `lib/features/auth/domain/repositories/i_auth_repository.dart`

**Step 1: Write the failing test**

In `test/features/auth/data/repositories/auth_repository_test.dart`, add inside the `group('IAuthRepository', ...)` block (after the `signOut` group):

```dart
group('deleteAccount', () {
  test('completes without error', () async {
    when(
      () => mockAuthRepository.deleteAccount(),
    ).thenAnswer((_) async {});

    await expectLater(mockAuthRepository.deleteAccount(), completes);

    verify(() => mockAuthRepository.deleteAccount()).called(1);
  });

  test('throws AppException on failure', () async {
    when(
      () => mockAuthRepository.deleteAccount(),
    ).thenThrow(
      const AppException.auth(message: 'Failed to delete account'),
    );

    expect(
      () => mockAuthRepository.deleteAccount(),
      throwsA(isA<AppException>()),
    );
  });
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/data/repositories/auth_repository_test.dart --no-pub`
Expected: FAIL — `The method 'deleteAccount' isn't defined for the class 'MockAuthRepository'`

**Step 3: Add `deleteAccount()` to the interface**

In `lib/features/auth/domain/repositories/i_auth_repository.dart`, add after `resetPassword`:

```dart
Future<void> deleteAccount();
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/data/repositories/auth_repository_test.dart --no-pub`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/auth/domain/repositories/i_auth_repository.dart \
        test/features/auth/data/repositories/auth_repository_test.dart
git commit -m "feat(auth): add deleteAccount to IAuthRepository interface + tests"
```

---

### Task 3: Data — implement `deleteAccount()` in repository

**Files:**
- Modify: `lib/features/auth/data/repositories/auth_repository.dart`

**Step 1: Add the implementation**

In `auth_repository.dart`, add after the `signOut()` method:

```dart
@override
Future<void> deleteAccount() async {
  try {
    await _supabase.functions.invoke('delete-account');
    await _revenuecatLogOut();
  } on FunctionException catch (e) {
    throw AppException.auth(
      message: e.details?.toString() ?? 'Failed to delete account',
    );
  } on AppException {
    rethrow;
  } catch (e) {
    throw AppException.auth(message: e.toString());
  }
}
```

**Step 2: Verify no analysis warnings**

Run: `flutter analyze lib/features/auth/data/repositories/auth_repository.dart`
Expected: `No issues found!`

**Step 3: Commit**

```bash
git add lib/features/auth/data/repositories/auth_repository.dart
git commit -m "feat(auth): implement deleteAccount in AuthRepository

Invokes delete-account edge function, then logs out RevenueCat.
Wraps FunctionException → AppException.auth for consistent error handling."
```

---

### Task 4: ViewModel — add `deleteAccount()` to AuthViewModel

**Files:**
- Modify: `lib/features/auth/presentation/view_models/auth_view_model.dart`

**Step 1: Write the failing test**

In `test/features/auth/presentation/view_models/auth_view_model_test.dart`, add a new `group('deleteAccount', ...)` block. Use the exact same `createSettledNotifier()` helper pattern from the `signInWithEmail validation` group (line ~208) — do NOT use `.future` (that only exists on `AsyncNotifier`, not on this sync `Notifier`):

```dart
group('deleteAccount', () {
  late _MockAuthRepository mockAuthRepo;
  late StreamController<supabase.AuthState> authStreamController;
  late ProviderContainer container;

  setUp(() {
    mockAuthRepo = _MockAuthRepository();
    authStreamController = StreamController<supabase.AuthState>.broadcast();
    when(
      () => mockAuthRepo.onAuthStateChange,
    ).thenAnswer((_) => authStreamController.stream);
    when(
      () => mockAuthRepo.getCurrentUserWithProfile(),
    ).thenAnswer((_) async => null);
  });

  tearDown(() {
    container.dispose();
    authStreamController.close();
  });

  // Mirrors createSettledNotifier() from signInWithEmail validation group.
  // Polls until _checkAuthentication() settles out of initial/authenticating.
  Future<AuthViewModel> createSettledNotifier() async {
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(mockAuthRepo)],
    )..listen(authViewModelProvider, (_, __) {});
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
      final state = container.read(authViewModelProvider);
      if (state is! AuthStateInitial && state is! AuthStateAuthenticating) {
        break;
      }
    }
    return container.read(authViewModelProvider.notifier);
  }

  test('sets state to unauthenticated on success', () async {
    when(() => mockAuthRepo.deleteAccount()).thenAnswer((_) async {});

    final notifier = await createSettledNotifier();
    await notifier.deleteAccount();

    expect(
      container.read(authViewModelProvider),
      isA<AuthStateUnauthenticated>(),
    );
  });

  test('rethrows exception on failure without clearing state', () async {
    when(() => mockAuthRepo.deleteAccount()).thenThrow(
      const AppException.auth(message: 'Failed to delete account'),
    );

    final notifier = await createSettledNotifier();

    expect(
      () => notifier.deleteAccount(),
      throwsA(isA<AppException>()),
    );
  });
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/presentation/view_models/auth_view_model_test.dart --no-pub`
Expected: FAIL — `The method 'deleteAccount' isn't defined`

**Step 3: Add `deleteAccount()` to AuthViewModel**

In `auth_view_model.dart`, add after the `signOut()` method:

```dart
Future<void> deleteAccount() async {
  try {
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.deleteAccount();
  } on Object catch (e, st) {
    await SentryConfig.captureException(e, stackTrace: st);
    rethrow; // Do not clear state — account was not deleted
  }
  // Only reached on success
  invalidateUserScopedProviders(ref);
  state = const AuthState.unauthenticated();
  _notifyRouter();
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/presentation/view_models/auth_view_model_test.dart --no-pub`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/features/auth/presentation/view_models/auth_view_model.dart \
        test/features/auth/presentation/view_models/auth_view_model_test.dart
git commit -m "feat(auth): add deleteAccount to AuthViewModel

Rethrows on failure (account not deleted — state must not be cleared).
Clears user-scoped providers and routes to login only on success."
```

---

### Task 5: UI — add Delete Account tile to SettingsSections

**Files:**
- Modify: `lib/features/settings/presentation/widgets/settings_sections.dart`

**Step 1: Add `onDeleteAccount` parameter**

In `settings_sections.dart`, add to the constructor parameters (after `onRestore`):

```dart
final VoidCallback onDeleteAccount;
```

And add it to the constructor signature after `onRestore`:

```dart
required this.onDeleteAccount,
```

**Step 2: Add the Delete Account tile**

Inside the Account section `SettingsCard`, add after the `Credit History` tile (before the closing `]` of the card's children list):

```dart
SettingsDivider(isDark: isDark),
SettingsTile(
  icon: Icons.delete_forever_outlined,
  iconBgColor: AppColors.error,
  title: 'Delete Account',
  trailing: SettingsChevronArrow(isDark: isDark),
  isDark: isDark,
  onTap: onDeleteAccount,
),
```

**Step 3: Fix `settings_sections_test.dart` — REQUIRED or ALL settings tests break**

`buildWidget()` helper at line ~18 of the test file uses `SettingsSections(...)` without the new `onDeleteAccount` param. Adding `required this.onDeleteAccount` breaks compilation of the entire test file. Fix by adding the param to `buildWidget()`:

In `test/features/settings/presentation/widgets/settings_sections_test.dart`, update `buildWidget()`:

```dart
// In buildWidget(), add onDeleteAccount to the SettingsSections call:
child: SettingsSections(
  email: email,
  isDark: isDark,
  version: version,
  isLoggedIn: isLoggedIn,
  isPremium: isPremium,
  onResetPassword: () {},
  onSignOut: () {},
  onRestore: () {},
  onDeleteAccount: () {},  // ADD THIS
),
```

Then add two widget tests inside the `group('SettingsSections', ...)` block:

```dart
testWidgets('shows Delete Account tile when logged in', (tester) async {
  await tester.pumpWidget(buildWidget());
  await tester.pumpAndSettle();

  expect(find.text('Delete Account'), findsOneWidget);
});

testWidgets('hides Delete Account tile when not logged in', (tester) async {
  await tester.pumpWidget(buildWidget(isLoggedIn: false));
  await tester.pumpAndSettle();

  expect(find.text('Delete Account'), findsNothing);
});
```

**Step 4: Run widget tests to verify they pass**

Run: `flutter test test/features/settings/presentation/widgets/settings_sections_test.dart --no-pub`
Expected: All tests pass (including the 2 new Delete Account tests)

**Step 5: Verify no analysis warnings**

Run: `flutter analyze lib/features/settings/presentation/widgets/settings_sections.dart`
Expected: `No issues found!`

---

### Task 6: UI — wire `_deleteAccount()` in SettingsScreen

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`

**Step 1: Add `_deleteAccount()` method**

In `settings_screen.dart`, add after `_signOut()`:

```dart
Future<void> _deleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Account?'),
      content: const Text(
        'This will permanently delete your account and all generated images. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed ?? false) {
    setState(() => _isLoading = true);
    try {
      await ref.read(authViewModelProvider.notifier).deleteAccount();
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppExceptionMapper.toUserMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
```

**Step 2: Pass callback to SettingsSections**

In `settings_screen.dart`, find the `SettingsSections(...)` widget and add the callback (after `onRestore`):

```dart
onDeleteAccount: () => _deleteAccount(context),
```

**Step 3: Verify no analysis warnings**

Run: `flutter analyze lib/features/settings/ --no-pub`
Expected: `No issues found!`

**Step 4: Commit**

```bash
git add lib/features/settings/presentation/widgets/settings_sections.dart \
        lib/features/settings/presentation/settings_screen.dart \
        test/features/settings/presentation/widgets/settings_sections_test.dart
git commit -m "feat(settings): add Delete Account tile with confirmation dialog

Single-step confirmation per design: warns about permanent data loss.
Follows signOut() pattern: loading overlay + error snackbar on failure."
```

---

### Task 7: Final verification

**Step 1: Run full test suite**

Run: `flutter test --no-pub`
Expected: All tests pass, 0 failures

**Step 2: Run analysis on entire project**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

**Step 3: Final commit (if any loose files)**

If everything is clean, no extra commit needed. All changes were committed atomically per task.

---

## NOT in scope
- GDPR data export before deletion (→ TODOS.md, P3)
- Soft-delete / grace period / undo window
- Admin-side deletion via Admin app
- Cancelling RevenueCat subscription server-side (user manages via store)

## What already exists
- `_revenuecatLogOut()` — reused directly, already non-blocking with try/catch
- `invalidateUserScopedProviders()` — reused directly
- `signOut()` pattern in `AuthViewModel` — `deleteAccount()` mirrors it
- `FunctionException` pattern — used in `credit_repository.dart`, `gallery_repository.dart`
- `createSettledNotifier()` — copy-paste from existing `signInWithEmail validation` group

## Dream state delta
After this plan: Store-compliant (account deletion ✅). Gap to 12-month ideal: GDPR data export + deletion confirmation email.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | ISSUES_FIXED | 2 critical bugs fixed, 1 storage gap fixed, 1 item deferred to TODOS |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR | 3 fixes applied (pagination, missing commit, missing test step) |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | — |

**ENG FIXES:** (1) Storage list now paginated (loop until empty) — handles users with >1000 images, (2) Task 6 commit now includes `settings_sections_test.dart` — was never committed, (3) Task 5 now runs widget tests before analyze
**VERDICT:** CEO + ENG CLEARED — ready to implement

## Deploy Note

Edge function requires `--no-verify-jwt` flag (same reason as all other Flutter-called functions — ES256/HS256 mismatch):

```bash
supabase functions deploy delete-account --no-verify-jwt
```
