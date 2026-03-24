# Admin Dashboard Implementation Plan (Executable)

Date: 2026-03-24
Input Design: docs/plans/2026-03-24-admin-dashboard-production-design.md
Execution Mode: Batch execution with architect checkpoints
Constraint: Firebase Spark-compatible (no Blaze-only backend requirements)

## 0. Preconditions

1. Do not execute on main/master without explicit approval.
2. Create isolated worktree before any code edits.
3. Keep all security-sensitive moderation enforcement in Firestore rules.
4. Use TDD-first for each task: write/adjust test, run test (red), implement, run test (green).

## 1. Standard Verification Commands

Run from project root unless specified.

```bash
flutter analyze
flutter test test/navigation test/providers test/repositories test/screens test/widgets
```

For rules/functions-related checks:

```bash
cd functions
npm test
cd ..
firebase deploy --project archives-zzzz --only firestore:rules
```

## 2. Task Batches

### Batch 1 (Foundation Security + Data Contracts)

#### Task 1: Tighten user moderation field rules
Files:
- firestore.rules
- test/rules (create if missing)

Steps:
1. Lock user writable fields by role (`user` safe profile subset, `admin` moderation subset).
2. Enforce self-role-change denial.
3. Enforce suspension field consistency (`suspensionType` + `suspensionUntil`).

Verification:
1. Rules tests for user self-profile allowed.
2. Rules tests for non-admin moderation denied.
3. Rules tests for admin moderation allowed.

Done when:
- All new rules tests pass and no privilege escalation path exists.

#### Task 2: Tighten report status transition rules
Files:
- firestore.rules
- test/rules (create/extend)

Steps:
1. Allow report creation by authenticated users with required fields.
2. Restrict report update transitions to admins only.
3. Validate status transitions: `open -> under_review -> resolved`.

Verification:
1. Reporter can create own report.
2. Non-admin cannot update status/review fields.
3. Admin can perform valid transitions; invalid transitions fail.

Done when:
- Transition matrix tests pass.

#### Task 3: Ensure immutable client audit-log policy
Files:
- firestore.rules
- test/rules

Steps:
1. Keep admin read access for `moderation_audit_logs`.
2. Deny all client creates/updates/deletes for audit logs.
3. Confirm list/get behavior remains admin-only.

Verification:
1. Admin read allowed.
2. User read denied.
3. Any client write denied.

Done when:
- Audit log read/write policy tests pass.

Checkpoint output:
- Show changed files.
- Paste rules test summary.
- State: Ready for feedback.

### Batch 2 (Repository Layer Hardening)

#### Task 4: Add moderation action enums/constants
Files:
- lib/core/constants (new/extend)
- lib/models (if shared enum model needed)
- test/models or test/core

Steps:
1. Add typed constants for report statuses, suspension types, action types.
2. Replace raw strings in repository code where practical.

Verification:
1. Unit tests for enum/string mapping if adapters exist.
2. flutter analyze clean.

Done when:
- No raw magic strings in core moderation flows.

#### Task 5: Harden user repository moderation writes
Files:
- lib/repositories/user_repository.dart
- test/repositories/user_repository_test.dart (create/extend)

Steps:
1. Enforce client-side input validation before writes.
2. Enforce no self-role change at repository guard level.
3. Normalize update payloads and timestamps.

Verification:
1. Tests for suspend/unsuspend/setRole success path.
2. Tests for self-role change rejection.
3. Tests for invalid duration/type rejection.

Done when:
- Repository tests pass and analyzer is clean.

#### Task 6: Harden report repository moderation writes
Files:
- lib/repositories/report_repository.dart
- test/repositories/report_repository_test.dart (create/extend)

Steps:
1. Validate required review fields and allowed status transitions client-side.
2. Keep status write payload minimal and deterministic.
3. Normalize resolution notes handling.

Verification:
1. Tests for valid review transitions.
2. Tests for invalid transitions rejection.
3. Tests for malformed payload rejection.

Done when:
- Repository tests pass for transition + validation behavior.

Checkpoint output:
- Show changed files.
- Paste repository test and analyze summary.
- State: Ready for feedback.

### Batch 3 (Provider and Route Guard Assurance)

#### Task 7: Provider command-state reliability
Files:
- lib/providers/user_providers.dart
- lib/providers/report_providers.dart
- test/providers/* (create/extend)

Steps:
1. Ensure loading/success/error transitions are deterministic.
2. Add retry-safe state reset behavior.
3. Standardize exception-to-message mapping.

Verification:
1. Provider tests for success and error transitions.
2. Provider tests for retry behavior.

Done when:
- Provider state machine tests pass.

#### Task 8: Admin route guard regression suite
Files:
- lib/providers/router_provider.dart
- test/navigation/router_* (create/extend)

Steps:
1. Confirm admin-only shell is inaccessible to non-admin users.
2. Confirm unauthenticated users redirect to login.
3. Confirm admin user can access all admin routes.

Verification:
1. Route tests for unauthenticated/non-admin/admin matrices.

Done when:
- Route guard tests pass across all matrices.

#### Task 9: Shared moderation error contract
Files:
- lib/core/errors (new/extend)
- lib/screens/admin/admin_users_screen.dart
- lib/screens/admin/admin_reports_screen.dart
- test/screens/admin/* (create/extend)

Steps:
1. Define a small typed error contract for moderation actions.
2. Map repository/provider errors to explicit admin-facing messages.
3. Ensure transient failures expose retry actions.

Verification:
1. Widget tests for key error states and retry UI.
2. flutter analyze clean.

Done when:
- Admin screens consistently surface actionable failures.

Checkpoint output:
- Show changed files.
- Paste provider/navigation/screen test summary.
- State: Ready for feedback.

### Batch 4 (Admin UI Completion)

#### Task 10: Overview metrics cards and deltas
Files:
- lib/screens/admin (overview screen)
- lib/widgets/admin (new shared cards)
- test/screens/admin/overview_test.dart

Steps:
1. Add KPI cards for open reports, avg resolution, suspensions/day, removals/day.
2. Add day-over-day delta indicator format.
3. Implement loading/empty/error states.

Verification:
1. Widget tests for loading/empty/data/error states.

Done when:
- Overview screen renders all required KPIs with fallback states.

#### Task 11: Reports queue advanced filters + exact search
Files:
- lib/screens/admin/admin_reports_screen.dart
- lib/widgets/admin (filter/search widgets)
- test/screens/admin/reports_screen_test.dart

Steps:
1. Add exact search by target ID/reporter ID.
2. Add advanced filters (status, reason, target type, date range).
3. Ensure filter chip state is stable across refresh.

Verification:
1. Widget tests for search/filter interaction.
2. Tests for filter persistence through state updates.

Done when:
- Reports queue supports exact search + advanced filtering as designed.

#### Task 12: Users moderation action panel completion
Files:
- lib/screens/admin/admin_users_screen.dart
- lib/widgets/admin (action panel/dialogs)
- test/screens/admin/users_screen_test.dart

Steps:
1. Add/complete warn, strike, temporary suspend, permanent suspend, unsuspend flows.
2. Require reason in confirmation dialogs.
3. Prevent duplicate action submission with local action lock.

Verification:
1. Widget tests for each moderation action path.
2. Widget tests for reason-required validation.

Done when:
- All user moderation actions are test-covered and stable.

Checkpoint output:
- Show changed files.
- Paste screen/widget test summary.
- State: Ready for feedback.

### Batch 5 (Observability + Release Readiness)

#### Task 13: Audit log screen and query constraints
Files:
- lib/screens/admin (audit log screen)
- lib/repositories (audit read methods)
- test/screens/admin/audit_log_screen_test.dart

Steps:
1. Add admin audit timeline with filters (actor/action/date).
2. Ensure immutable presentation and clear target metadata.
3. Handle pagination/limit safely.

Verification:
1. Widget tests for list rendering and filters.
2. Repository tests for query constraints.

Done when:
- Audit screen is admin-readable and stable for large datasets.

#### Task 14: End-to-end moderation scenario suite
Files:
- test/e2e/admin_moderation_flow_test.dart (create/extend)

Steps:
1. Cover report creation by user.
2. Cover admin review lifecycle transition.
3. Cover user moderation action and post moderation action.

Verification:
1. Run targeted e2e suite.

Done when:
- Core moderation journey is green end-to-end.

#### Task 15: Release checklist and rollback notes
Files:
- docs/plans/2026-03-24-admin-dashboard-production-design.md
- docs/plans/2026-03-24-admin-dashboard-release-checklist.md (new)

Steps:
1. Add release checklist: tests, rules deploy, smoke checks.
2. Add rollback notes for rule regression and UI disable path.
3. Record post-release monitoring checks.

Verification:
1. Verify checklist completeness against acceptance criteria.

Done when:
- Release checklist is complete and actionable.

Checkpoint output:
- Show changed files.
- Paste final verification summary.
- State: Ready for feedback.

## 3. Execution Rules

1. Execute one batch at a time.
2. Stop immediately on blockers or repeated verification failures.
3. Do not skip batch checkpoint reviews.
4. Keep changes minimal and scoped to the active tasks.

## 4. Completion Condition

All 15 tasks completed, all verification commands passing, and checkpoints reviewed after each batch.

After completion:
- Use finishing workflow to present merge/PR/keep/discard options with evidence.
