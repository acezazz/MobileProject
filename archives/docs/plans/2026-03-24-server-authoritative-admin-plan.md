# Server-Authoritative Admin Security Plan

Date: 2026-03-24
Design Basis: Approved redesign to move all admin-sensitive actions to trusted server commands.
Priority: Maximum security first.

## Context Map: Move Admin and Moderation Authority to Server

### Primary Files (Direct Modifications)
- `functions/index.js` - Add callable commands for report creation, report moderation, user suspension, and role assignment with transactional writes.
- `functions/package.json` - Add any required validation/logging dependencies for secure command handlers.
- `lib/repositories/report_repository.dart` - Replace direct Firestore writes with callable function invocation wrappers.
- `lib/repositories/user_repository.dart` - Replace direct suspension/role writes with callable command invocation wrappers.
- `lib/providers/report_providers.dart` - Keep provider API but route execution through updated repository commands.
- `lib/providers/user_providers.dart` - Keep notifier API while switching implementation source to callable results.
- `pubspec.yaml` - Add `cloud_functions` dependency for callable command clients.
- `firestore.rules` - Deny direct client writes to sensitive collections and fields.

### Affected Files (Likely Updates)
- `lib/screens/admin/admin_reports_screen.dart` - Keep UX behavior but surface command failures with precise error messaging.
- `lib/screens/admin/admin_users_screen.dart` - Keep UX behavior but map command responses to explicit moderation feedback.
- `lib/screens/report/report_screen.dart` - Keep user flow while command submission replaces direct report write.
- `lib/core/constants/firestore_constants.dart` - Confirm constants for audit collection and optional command metadata paths.
- `firestore.indexes.json` - Validate indexes still match admin queue reads after schema hardening.

### Existing Dependency Findings
- Cloud Functions already exist and use Admin SDK (`functions/index.js`), so command extension aligns with current backend style.
- Client currently performs direct writes for report and moderation paths (`lib/repositories/report_repository.dart`, `lib/repositories/user_repository.dart`).
- Firestore rules currently allow admin-level direct client updates for reports/users, which is the trust-boundary flaw.
- Flutter app currently has no `cloud_functions` dependency; callable client layer must be introduced.

### Inbound/Outbound Dependency Traces
Inbound to new commands:
- UI (`admin_reports_screen`, `admin_users_screen`, `report_screen`) -> providers -> repositories -> callable commands.

Outbound from new commands:
- `reports` collection updates.
- `users` status/role updates.
- `moderation_audit_logs` append-only writes.

Security boundary after redesign:
- Client SDK can read allowed data.
- Sensitive write authority resides in trusted server commands only.

### Test Coverage Reality
- Existing new tests only cover role helpers and route redirects.
- No current tests for callable command behavior, rules denial paths, or transactional audit guarantees.

### Suggested Change Order
1. Introduce server command contracts and implement backend callable handlers.
2. Harden Firestore rules to block direct client sensitive writes.
3. Update Flutter repositories to call backend commands.
4. Keep provider/screen contracts stable while adapting errors and states.
5. Add emulator tests for rules and command behavior.
6. Run staged rollout with feature toggles and backout path.

### Risks
- Partial migration can break admin actions if rules are tightened before client switches to commands.
- Missing idempotency guards can duplicate audit entries on retries.
- Role checks in backend must not rely on mutable client payload fields.
- Callable timeouts/retries can produce UX regressions if not surfaced clearly.

### Self-Reflection (终省)
- Missing dependency check: no callable client dependency in Flutter yet.
- Blast radius: high (backend API contract, security rules, repositories, admin UX).
- Measure check: split into independently verifiable tasks with clear deploy gates and rollback points.

## Task Decomposition (2-5 min tasks, TDD-first)

## Phase A - Command Contracts and Backend Security Core

### Task A1 - Define command contracts and validation schema
Files:
- `functions/index.js`
- `docs/plans/2026-03-24-server-authoritative-admin-plan.md` (append command contract section during execution)

Steps:
1. Define callable command names and request/response schema:
   - `createReport`
   - `reviewReport`
   - `suspendUser`
   - `unsuspendUser`
   - `setUserRole`
2. Define uniform error codes: `permission-denied`, `failed-precondition`, `invalid-argument`, `not-found`.
3. Add strict payload validation before any write.

Test-first:
1. Add backend tests (or emulator scripts) for invalid payload rejection.
2. Verify each command returns stable error shape.

Verify command:
```bash
cd functions
npm test
```
Expected: invalid payloads fail with deterministic codes.

### Task A2 - Implement transactional write handlers
Files:
- `functions/index.js`

Steps:
1. Implement each callable with server-side actor role checks from Firestore.
2. Use transaction/batch per command to update target state and write audit log atomically.
3. Add idempotency key support for moderation commands (request hash or caller-provided key) to avoid duplicated side effects.

Test-first:
1. Add tests for atomicity: if audit write fails, target update does not commit.
2. Add tests for role boundaries:
   - user denied
   - admin allowed for moderation
   - super admin required for role changes

Verify command:
```bash
cd functions
npm test
```
Expected: transaction and authorization tests pass.

### Task A3 - Add callable auth hardening
Files:
- `functions/index.js`

Steps:
1. Require authenticated caller for all commands.
2. Resolve actor profile by `context.auth.uid` only.
3. Ignore any client-provided actor identity.

Test-first:
1. Test unauthenticated command rejection.
2. Test spoofed actor payload ignored.

Verify command:
```bash
cd functions
npm test
```
Expected: unauthenticated and spoof attempts denied.

## Phase B - Firestore Rules Hard Cut to Server Authority

### Task B1 - Deny direct client writes to sensitive docs
Files:
- `firestore.rules`

Steps:
1. `reports`: allow create/update/delete from client as false.
2. `users`: deny role/status/suspension metadata changes from client writes.
3. `moderation_audit_logs`: keep append-only and deny client writes.
4. Retain non-sensitive user self-profile edit capability (explicit safe-field whitelist).

Test-first:
1. Add emulator rules tests for blocked direct report create/update.
2. Add emulator rules tests for blocked direct user role/status writes.
3. Add emulator rules tests for allowed safe profile updates.

Verify command:
```bash
firebase emulators:exec "npm --prefix functions test"
firebase deploy --only firestore:rules --dry-run
```
Expected: blocked sensitive writes and preserved safe profile writes.

### Task B2 - Revalidate report read policy
Files:
- `firestore.rules`

Steps:
1. Keep reporter self-read.
2. Keep admin read of moderation queue.
3. Confirm no leakage to non-admin/non-reporter users.

Test-first:
1. Emulator tests for read matrix (reporter/admin/non-owner user).

Verify command:
```bash
firebase emulators:exec "npm --prefix functions test"
```
Expected: read policy matrix passes.

## Phase C - Flutter Client Migration to Callable Commands

### Task C1 - Add callable dependency and service adapter
Files:
- `pubspec.yaml`
- `lib/services/` (new callable service file)

Steps:
1. Add `cloud_functions` dependency.
2. Create command service wrappers with typed request/response handling.
3. Map backend errors to domain exceptions.

Test-first:
1. Add service tests with mocked callable responses and errors.

Verify command:
```bash
flutter pub get
flutter test test/services
```
Expected: command wrapper tests pass.

### Task C2 - Migrate report repository to commands
Files:
- `lib/repositories/report_repository.dart`
- `lib/providers/report_providers.dart`

Steps:
1. Replace `_reportsRef.add` report create with `createReport` callable.
2. Replace moderation status updates with `reviewReport` callable.
3. Preserve read operations via Firestore query where appropriate.

Test-first:
1. Add repository tests for successful command invocation and failure mapping.
2. Ensure no direct write APIs remain.

Verify command:
```bash
flutter test test/services test/screens
```
Expected: report flows pass with callable backend.

### Task C3 - Migrate user moderation repository to commands
Files:
- `lib/repositories/user_repository.dart`
- `lib/providers/user_providers.dart`

Steps:
1. Replace suspend/unsuspend/setRole direct writes with callable commands.
2. Remove client-side direct audit writes.
3. Keep provider API unchanged for UI stability.

Test-first:
1. Add notifier tests for loading/success/error transitions.
2. Add repository tests for denied role change behavior.

Verify command:
```bash
flutter test test/services test/widgets
```
Expected: moderation actions execute through command path with proper errors.

## Phase D - UX and Operational Readiness

### Task D1 - Strengthen admin UX feedback
Files:
- `lib/screens/admin/admin_reports_screen.dart`
- `lib/screens/admin/admin_users_screen.dart`
- `lib/screens/report/report_screen.dart`

Steps:
1. Show clear error messages for permission, validation, and transient failures.
2. Disable repeated action taps during in-flight command execution.
3. Log command failures to diagnostics channel for support.

Test-first:
1. Widget tests for disabled states and error snackbars.

Verify command:
```bash
flutter test test/screens test/widgets
```
Expected: UX handles command failures predictably.

### Task D2 - Deployment sequence and rollback
Files:
- `docs/plans/2026-03-24-server-authoritative-admin-plan.md` (update checklist during execution)

Steps:
1. Deploy functions first (commands available, old client still works temporarily if rules unchanged).
2. Deploy app update that switches writes to commands.
3. Deploy hardened rules to deny direct sensitive writes.
4. Rollback plan:
   - If app issues occur, rollback app and keep functions.
   - Delay rules hard-cut until command adoption confirmed.

Manual verification checklist:
- Non-admin cannot perform moderation actions.
- Admin can review reports; super admin can assign roles.
- Audit records are present for every successful moderation command.
- Failed moderation command does not mutate target state.

## Commit Strategy (Non-interactive)
1. `feat(functions): add server-authoritative admin command handlers`
2. `feat(rules): deny direct sensitive client writes`
3. `feat(client): migrate report and moderation writes to callables`
4. `test(security): add emulator and repository coverage for command model`
5. `chore(ops): add rollout and rollback checklist for secure cutover`

## Spark-Compatible Notes
- Uses Firebase Functions + Firestore already present in project.
- No Blaze-only third-party services introduced in this design plan.
- Keep invocation volume and payload minimal to stay cost-aware.

## Status
DONE - Implementation plan saved for server-authoritative redesign.
