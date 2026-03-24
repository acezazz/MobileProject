# Admin Dashboard Production Design

Date: 2026-03-24
Status: Approved
Scope Source: Brainstorming decisions Q1-Q25

## 1. Goals and Non-Goals

### Goals
- Deliver a production-grade admin dashboard for web and mobile.
- Support one initial admin user with architecture that can scale to multiple admins.
- Keep enforcement Spark-compatible with Firestore rules as the hard boundary.
- Provide reliable moderation for users, reports, and posts with permanent auditability.

### Non-Goals
- No hard deletion of user accounts in this phase.
- No role hierarchy beyond `user` and `admin` in this phase.
- No migration to Blaze-dependent command backend in this phase.

## 2. Product Decisions (Locked)

- Platforms: Web and mobile.
- Initial admin count: one.
- Scale assumption: small scale initially.
- Access shell: strict admin-only shell.
- Post statuses: includes archived.
- Moderation default: auto-approve baseline.
- Content removal mode: soft removal.
- Suspension mode: mixed durations (temporary and permanent).
- User lifecycle: no hard delete.
- Report reason model: enum + freeform detail.
- Report workflow: `open`, `under_review`, `resolved`.
- Enforcement history: warning + strike model.
- Dashboard trend view: day-over-day.
- Refresh mode: hybrid realtime + snapshot query reads.
- Search mode: exact search.
- Filtering mode: advanced filtering.
- Audit visibility: all admins can view permanent logs.

## 3. Information Architecture

### Main Navigation
- Overview
- Users
- Reports
- Content Moderation
- Audit Log
- Settings

### Page Responsibilities
- Overview: KPI cards, queue pressure, day-over-day trend deltas.
- Users: search/filter users, view profile moderation state, apply suspend/unsuspend/role actions.
- Reports: triage queue by status and reason; assign handling; resolve with notes.
- Content Moderation: archive/unarchive, soft-remove/restore, and evidence review.
- Audit Log: immutable timeline of admin actions with actor, target, reason, and timestamp.
- Settings: safety defaults, filter presets, moderation templates.

## 4. Data Contracts and Firestore Model

### Collections
- `users/{uid}`
- `reports/{reportId}`
- `posts/{postId}`
- `moderation_audit_logs/{logId}`

### users document (minimum moderation fields)
- `role`: `user | admin`
- `isSuspended`: bool
- `suspensionType`: `none | temporary | permanent`
- `suspensionUntil`: timestamp|null
- `warningsCount`: number
- `strikesCount`: number
- `updatedAt`: timestamp

### reports document (minimum)
- `reporterId`: string
- `targetType`: `post | user | comment`
- `targetId`: string
- `reason`: enum
- `detail`: string
- `status`: `open | under_review | resolved`
- `reviewedBy`: string|null
- `reviewedAt`: timestamp|null
- `resolutionNote`: string|null
- `createdAt`: timestamp

### posts moderation fields
- `isRemoved`: bool
- `removedAt`: timestamp|null
- `removedBy`: string|null
- `isArchived`: bool
- `archivedAt`: timestamp|null
- `archivedBy`: string|null

### moderation audit log document
- `actionType`: enum
- `actorId`: string
- `targetType`: enum
- `targetId`: string
- `before`: map
- `after`: map
- `reason`: string
- `createdAt`: timestamp

## 5. Authorization and Security Boundary

### Enforcement model
- Firestore rules remain the source of enforcement for Spark compatibility.
- Client writes are permitted only when they satisfy strict admin predicates and field-level constraints.
- Self-privilege escalation is blocked (`request.auth.uid != targetUid` for role changes).

### Rule principles
- Deny by default.
- Whitelist only safe self-profile fields for normal users.
- Restrict moderation fields to admins only.
- Restrict report review state transitions to admins only.
- Deny all direct client writes to `moderation_audit_logs`.

### Session and routing
- Admin shell requires authenticated user with `role == admin`.
- Non-admin access to admin routes is redirected to user routes/login.

## 6. UX and Interaction Design

### Queue behavior
- Report queue defaults to `open` sorted by `createdAt` ascending.
- Fast filters: reason, target type, status, date range, escalation level.

### User moderation UX
- Inline action bar: warn, strike, suspend temporary, suspend permanent, unsuspend.
- Confirmation dialogs for destructive/high-impact actions.
- Mandatory reason input for moderation actions.

### Feedback and failure states
- Every action shows optimistic progress state and authoritative completion toast.
- Permission-denied, stale-data, and validation errors map to explicit admin-readable messages.
- Retry path available for transient failures.

## 7. Reliability and Observability

### Reliability
- Idempotent UI actions with local action lock to prevent duplicate taps.
- Server timestamp usage for all moderation state changes.
- Reconcile list views after writes to avoid stale queue rendering.

### Observability
- Track dashboard metrics: open reports, average resolution time, suspensions/day, removals/day.
- Day-over-day trend computation from timestamped events.
- Audit log is append-only and permanently retained.

## 8. Testing Strategy

### Automated
- Unit tests:
  - Role utilities and route guard decisions.
  - Repository moderation methods and error mapping.
  - Report status transition validation.
- Widget tests:
  - Admin shell guard behavior.
  - Users and reports screen action flows.
- Rules tests:
  - Non-admin denied for admin fields.
  - Admin allowed for approved moderation updates.
  - Self-role-change denied.
  - Audit log write denied from client.

### Manual
- End-to-end moderation scenario on web and mobile.
- Offline/reconnect checks for queue/list consistency.
- Multi-admin simulation readiness (even with one seeded admin account).

## 9. Rollout Plan

### Phase 1: Foundation hardening
- Finalize schema constraints and Firestore rules.
- Verify rule tests and analyzer/tests pass.

### Phase 2: Admin UX completion
- Complete overview/users/reports/content/audit screens.
- Add advanced filters and exact search.

### Phase 3: Reliability and telemetry
- Add trend cards and operational metrics.
- Validate audit completeness for all moderation actions.

### Phase 4: Production cutover
- Seed admin account through trusted process.
- Run checklist and publish with rollback note.

## 10. Acceptance Criteria

- Non-admins cannot access admin routes or mutate admin-only fields.
- Admin can complete all required moderation actions from dashboard.
- Report lifecycle supports open -> under_review -> resolved transitions.
- Audit entries are created/visible for every moderation action and remain immutable.
- Dashboard shows day-over-day trends and queue counts accurately.
- Web and mobile admin flows are functionally equivalent for core actions.

## 11. Risks and Mitigations

- Risk: Spark-only architecture limits server-side command patterns.
  - Mitigation: strict rule-level field controls and append-only audit policy.
- Risk: direct-write moderation can drift if rule predicates are weakened.
  - Mitigation: keep rule tests mandatory in CI before deploy.
- Risk: single-admin bottleneck.
  - Mitigation: preserve multi-admin-safe data model and audit visibility from day one.

## 12. Next Step

Generate the implementation plan from this approved design using small TDD-first tasks across rules, repositories, providers, and admin UI screens.
