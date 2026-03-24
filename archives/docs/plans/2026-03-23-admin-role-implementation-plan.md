# Admin Role Implementation Plan (Approved Design)

Date: 2026-03-23
Scope: In-app admin + super admin capabilities for moderation, user management, and app settings.
Constraint: Prefer Spark-compatible implementation (avoid new paid backend requirements).

## Context Map: Add Admin and Super Admin Controls

### Primary Files (Direct Modifications)
- `lib/models/user_model.dart` - Add role and moderation metadata fields.
- `lib/services/user_service.dart` - Add role-aware profile updates and reads.
- `lib/repositories/user_repository.dart` - Add admin actions (suspend/unsuspend, role assignment by super admin).
- `lib/repositories/report_repository.dart` - Add admin-only report queue actions (resolve/dismiss/escalate metadata).
- `lib/providers/auth_providers.dart` - Expose current role provider.
- `lib/providers/user_providers.dart` - Add providers for admin actions and role checks.
- `lib/providers/report_providers.dart` - Add pending reports stream/provider for moderation panel.
- `lib/providers/router_provider.dart` - Add admin route guards.
- `lib/screens/...` (new admin screens) - Admin dashboard, report queue, user actions, settings controls.
- `firestore.rules` - Enforce role-based read/write permissions.

### Affected Files (May Need Updates)
- `lib/core/constants/firestore_constants.dart` - Add constants for new moderation collections if introduced.
- `firestore.indexes.json` - Add any new compound indexes for admin queue filters.
- `functions/index.js` - Optional: only for privileged workflows that cannot be safely done client-side. Keep optional due Spark preference.

### Existing Dependencies and Constraints
- Reports already exist (`reports` collection + `ReportModel`, `ReportRepository`).
- User status already exists (`active`, `deactivated`, `suspended`) in `UserModel`.
- Router redirection logic exists in `resolveAppRedirect` and already has tests.
- Current rules do not support admin role checks.
- No existing admin screen/module found.

### Inbound/Outbound Dependency Highlights
- Inbound to role data: auth state -> current profile providers -> route protection -> admin UI visibility.
- Outbound from admin actions: updates to `users`, `reports`, and possibly `posts/comments` moderation state.
- Security boundary: Firestore rules must be the source of truth; UI checks are convenience only.

### Suggested Change Order
1. Data schema + model updates (`UserModel`, report action metadata).
2. Firestore rules for role checks and admin write paths.
3. Repository/service methods for admin operations.
4. Providers and route guards.
5. Admin screens and UX actions.
6. Tests (unit/router/repository/rules behavior).

### Risks
- Privilege escalation if rules trust client-only role fields without strict checks.
- Regression in existing user profile parsing if new fields are not backward-compatible.
- Over-broad admin writes (accidental delete/update beyond moderation intent).
- Route guard drift: hidden buttons but unguarded direct route access.

### Self-Reflection (终省)
- Missing dependency check: currently no dedicated audit log collection; add this before enabling destructive actions.
- Blast radius check: medium-high (auth profile, rules, routing, moderation data paths).
- Measure check: keep role model simple (`user`, `admin`, `superAdmin`) and expand only after stable moderation baseline.

## Task Decomposition (2-5 minutes each, test-first)

## Phase A - Types and Security Foundation

### Task A1 - Extend user role schema (backward-compatible)
Files:
- `lib/models/user_model.dart`

Steps:
1. Add `role` field with default `user` and safe parsing fallback.
2. Add optional moderation metadata fields (`suspendedAt`, `suspensionReason`, `updatedByAdminId`) as nullable.
3. Keep `fromMap` tolerant to missing legacy fields.

Test-first:
1. Add/update model tests in `test/models/` for missing role -> defaults to `user`.
2. Verify parse does not fail on legacy user docs.

Verify command:
```bash
flutter test test/models
```
Expected: model tests pass with old and new payloads.

### Task A2 - Add role helper and policy constants
Files:
- `lib/core/constants/` (new or existing constants file)

Steps:
1. Add role enum/string constants (`user`, `admin`, `superAdmin`).
2. Add helper predicates used by providers/router (`isAdminOrHigher`, `isSuperAdmin`).

Test-first:
1. Add tiny pure unit tests in `test/services/` or `test/navigation/` for role helper logic.

Verify command:
```bash
flutter test test/services test/navigation
```
Expected: helper logic passes all role boundary cases.

### Task A3 - Harden Firestore rules for role-based control
Files:
- `firestore.rules`

Steps:
1. Add reusable rule functions: `isOwner(userId)`, `isAdmin()`, `isSuperAdmin()` from user doc role.
2. Restrict user self-updates so normal users cannot set their own role.
3. Allow admin moderation writes only on approved fields (`status`, moderation metadata).
4. Allow super admin role assignment updates.
5. Restrict report queue reads/updates to admin+.

Test-first:
1. Add rules test plan notes (if emulator tests are not present yet) in checklist section below.
2. Validate syntactically with Firebase CLI.

Verify commands:
```bash
firebase emulators:exec "echo rules-check"
firebase deploy --only firestore:rules --dry-run
```
Expected: rules compile; unauthorized paths denied in emulator checks.

## Phase B - Repositories and Providers

### Task B1 - Add admin methods to user repository/service
Files:
- `lib/services/user_service.dart`
- `lib/repositories/user_repository.dart`
- `lib/providers/user_providers.dart`

Steps:
1. Add methods: `suspendUser`, `unsuspendUser`, `setUserRole` (super admin only).
2. Ensure writes are partial updates with explicit field whitelist.
3. Add Riverpod notifiers/providers for these actions.

Test-first:
1. Add repository tests in `test/services/` or `test/widgets/` with mocked service calls.
2. Validate provider state transitions: loading -> success/error.

Verify command:
```bash
flutter test test/services test/widgets
```
Expected: provider/repository tests pass and no regressions.

### Task B2 - Add report moderation methods
Files:
- `lib/repositories/report_repository.dart`
- `lib/providers/report_providers.dart`

Steps:
1. Add admin queue read methods (pending + filters).
2. Add moderation actions (`markReviewed`, `resolve`, `dismiss`) with `reviewedBy`, `reviewedAt`.
3. Keep existing user report submission flow unchanged.

Test-first:
1. Add tests for state/status transitions and mapping.
2. Ensure non-admin path remains submit-only.

Verify command:
```bash
flutter test test/services test/screens
```
Expected: report moderation behavior covered; submission flow unaffected.

## Phase C - Routing and UI

### Task C1 - Role-aware route guard
Files:
- `lib/providers/auth_providers.dart`
- `lib/providers/router_provider.dart`
- `test/router/router_guest_access_test.dart`
- `test/e2e/post_actions_smoke_test.dart`

Steps:
1. Expose current user role provider from profile stream.
2. Extend redirect logic for `/admin/*` routes:
   - guest -> login
   - logged-in non-admin -> home
   - admin/superAdmin -> allow
3. Keep existing guest behavior unchanged.

Test-first:
1. Extend current redirect tests with admin route scenarios.
2. Add explicit case for logged-in non-admin access denial.

Verify command:
```bash
flutter test test/router test/e2e
```
Expected: all existing redirect tests remain green plus new admin cases.

### Task C2 - Build minimal admin dashboard
Files:
- `lib/screens/admin/` (new files)
- `lib/providers/router_provider.dart` (new routes)

Steps:
1. Add admin home screen with cards: Reports, Users, Settings.
2. Add report queue screen with status update actions.
3. Add user moderation screen (suspend/unsuspend).
4. Add super admin-only role management section.

Test-first:
1. Add widget tests for role-gated UI visibility.
2. Add smoke test for navigation to `/admin` routes.

Verify command:
```bash
flutter test test/screens test/widgets
```
Expected: admin screens render and actions dispatch with correct guards.

## Phase D - Auditability and Rollout Safety

### Task D1 - Add moderation audit log writes
Files:
- `lib/repositories/user_repository.dart`
- `lib/repositories/report_repository.dart`
- Optional: `lib/core/constants/firestore_constants.dart`

Steps:
1. On each admin action, write audit record (`actorId`, `action`, `targetId`, `timestamp`, `reason`).
2. Keep audit collection append-only by rules.

Test-first:
1. Add tests that confirm audit payload shape.

Verify command:
```bash
flutter test test/services
```
Expected: audit writes are triggered for each moderation path.

### Task D2 - Add deployment checklist and staged rollout
Files:
- `docs/plans/2026-03-23-admin-role-implementation-plan.md` (this file, checklist section updates during execution)

Steps:
1. Seed first super admin manually in Firestore user doc (`role: superAdmin`) under controlled process.
2. Deploy rules first, then app update.
3. Validate with test accounts (`user`, `admin`, `superAdmin`).

Manual verification checklist:
- User cannot access `/admin` routes.
- Admin can review reports and suspend users.
- Admin cannot assign roles.
- Super admin can assign roles.
- Audit log records every admin action.

## Commit Strategy (Non-interactive)
1. `feat(auth): add role-aware user model and helpers`
2. `feat(rules): enforce admin and super admin permissions`
3. `feat(moderation): add report and user admin actions`
4. `feat(router): guard admin routes by role`
5. `feat(ui): add admin dashboard and moderation screens`
6. `test(admin): cover role guards and moderation flows`

## Spark-Compatible Decisions
- Keep role source in Firestore `users/{uid}.role` and enforce via Firestore rules.
- Avoid introducing mandatory callable functions for role checks.
- Use Cloud Functions only if strictly needed for privileged server-side operations; keep optional.

## Status
DONE - Plan created and saved.
