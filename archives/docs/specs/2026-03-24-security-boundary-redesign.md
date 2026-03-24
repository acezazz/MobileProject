# Security Boundary Redesign Spec

Date: 2026-03-24
Status: Draft for approval

## 1) Problem Statement

Current flaw: sensitive admin and moderation flows are not fully isolated behind a trusted server boundary.

Goal: make server-side commands the write authority for all sensitive actions while using role claims only as a fast-path cache.

## 2) Approved Direction (from discovery)

- Primary flaw: Security boundary gap.
- Authority model: Full server authority for sensitive writes.
- Priority: Maximum security.
- Chosen approach: Command-only mutations plus role claims cache.
- Claims mismatch policy: Trust claims within short TTL.
- TTL selected: 1 minute.

## 3) Target Architecture

### 3.1 Trust boundary

- Client can read allowed documents.
- Client cannot directly create or update sensitive report, moderation, or role fields.
- All sensitive mutations pass through callable commands.

### 3.2 Command surface

- createReport
- reviewReport
- suspendUser
- unsuspendUser
- setUserRole

### 3.3 Authorization model

- Source of authority: server validation in command handlers.
- Fast path: role claims accepted only if claimAge <= 1 minute.
- Fallback path: if claim missing/expired, resolve role from Firestore user document.
- Mismatch handling:
  - if claim role and Firestore role disagree within TTL, reject command and require token refresh.
  - all mismatch rejects are audit-logged.

### 3.4 Consistency and integrity

- Each command executes target mutation and audit write in one transaction.
- No client-originated writes to moderation_audit_logs.
- Command inputs validated with strict schema and fixed enum constraints.

## 4) Benefits and Costs

### Approach selected: Command-only plus claims cache

Benefits:
- Strong server write boundary for sensitive paths.
- Better perceived latency for role checks when claim is fresh.
- Clear rollback and migration from current repository/provider flow.

Costs:
- More auth state edge cases (claim age, refresh timing).
- Additional operational logic for claim issuance and invalidation.
- Higher backend complexity than command-only without claims.

## 5) Security Policies

- Deny by default for sensitive writes in Firestore rules.
- Reject unauthenticated calls.
- Reject invalid payloads with stable error codes.
- Reject privilege escalation attempts.
- Keep role changes super-admin only.

## 6) Operational Rules

- Claims TTL hard cap: 1 minute.
- Any privilege downgrade must trigger immediate claim invalidation workflow.
- If command receives stale claim, command must fail safe and return explicit refresh-required error code.

## 7) Testing Requirements

- Command unit tests:
  - unauthenticated rejection
  - role boundary checks
  - invalid payload checks
  - transactional atomicity checks
  - mismatch claim-vs-Firestore rejection
- Emulator rule tests:
  - deny direct client writes on reports/users sensitive fields/audit logs
  - allow safe self-profile edits only
- Client tests:
  - callable error mapping
  - refresh-required UX handling

## 8) Rollout Strategy

1. Deploy command handlers and claim validation logic.
2. Ship client callable migration with explicit error handling.
3. Harden rules to deny direct sensitive writes.
4. Enable claim cache checks with 1-minute TTL.
5. Monitor mismatch/refresh-required rates and tune UX prompts.

## 9) Blind Spots Check

- Clock skew impact on 1-minute TTL must be measured.
- Token refresh UX friction may be non-trivial for admin-heavy sessions.
- Incident tooling should include claim mismatch dashboards.

## 10) Handoff

If approved, next step is a concrete implementation plan with phased TDD tasks under docs/plans.
