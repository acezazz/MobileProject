const ALLOWED_REPORT_TYPES = new Set(["post", "user", "comment", "message"]);
const ALLOWED_REVIEW_STATUSES = new Set(["reviewed", "resolved", "dismissed"]);
const ALLOWED_ROLES = new Set(["user", "admin"]);
const CLAIM_TTL_MS = 60 * 1000;

function assertNonEmptyString(value, fieldName, HttpsError) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} must be a non-empty string.`);
  }
}

function assertAuthenticated(context, HttpsError) {
  if (!context || !context.auth || !context.auth.uid) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }
  return context.auth.uid;
}

async function getActorRole(db, uid) {
  const actorDoc = await db.collection("users").doc(uid).get();
  if (!actorDoc.exists) {
    return null;
  }
  const data = actorDoc.data() || {};
  return data.role || null;
}

function ensureAdminOrHigher(role, HttpsError) {
  if (role !== "admin") {
    throw new HttpsError("permission-denied", "Admin permission required.");
  }
}

function parseOptionalIdempotencyKey(value) {
  if (typeof value !== "string") {
    return null;
  }
  const key = value.trim();
  return key.length > 0 ? key : null;
}

function getFreshClaimRole(context, nowMs) {
  const token = context?.auth?.token || {};
  const role = typeof token.role === "string" ? token.role.trim() : "";
  if (!role) {
    return null;
  }

  const rawIssuedAtMs = token.roleIssuedAtMs ?? token.roleRefreshedAtMs;
  const issuedAtMs = Number(rawIssuedAtMs);
  if (!Number.isFinite(issuedAtMs)) {
    return null;
  }

  const ageMs = nowMs - issuedAtMs;
  if (ageMs < 0 || ageMs > CLAIM_TTL_MS) {
    return null;
  }

  return role;
}

async function resolveActorRole({ db, actorId, context, HttpsError, createId, nowDate }) {
  const firestoreRole = await getActorRole(db, actorId);
  const claimRole = getFreshClaimRole(context, nowDate.getTime());

  if (claimRole && firestoreRole && claimRole !== firestoreRole) {
    await db.collection("moderation_audit_logs").doc(createId()).set({
      actorId,
      action: "auth_role_mismatch",
      targetId: actorId,
      claimRole,
      firestoreRole,
      timestamp: nowDate,
    });
    throw new HttpsError(
      "failed-precondition",
      "Role changed. Refresh authentication and retry.",
    );
  }

  return claimRole || firestoreRole;
}

function buildIdempotencyDocId(actorId, action, targetId, key) {
  return `${actorId}_${action}_${targetId}_${key}`;
}

function buildAdminCommandHandlers(options = {}) {
  const {
    getDb,
    HttpsError,
    now,
    nowIso = () => new Date().toISOString(),
    newId,
  } = options;

  if (typeof getDb !== "function") {
    throw new Error("buildAdminCommandHandlers requires getDb option.");
  }

  if (typeof HttpsError !== "function") {
    throw new Error("buildAdminCommandHandlers requires HttpsError option.");
  }

  const createId =
    typeof newId === "function"
      ? newId
      : () => getDb().collection("moderation_audit_logs").doc().id;

  const getNowDate =
    typeof now === "function"
      ? () => {
          const value = now();
          return value instanceof Date ? value : new Date(value);
        }
      : () => new Date(nowIso());

  async function createReport(data, context) {
    const reporterId = assertAuthenticated(context, HttpsError);
    assertNonEmptyString(data?.reportedId, "reportedId", HttpsError);
    assertNonEmptyString(data?.type, "type", HttpsError);
    assertNonEmptyString(data?.reason, "reason", HttpsError);

    const type = data.type.trim();
    if (!ALLOWED_REPORT_TYPES.has(type)) {
      throw new HttpsError("invalid-argument", "Invalid report type.");
    }

    if (reporterId === data.reportedId) {
      throw new HttpsError("failed-precondition", "Cannot report yourself.");
    }

    const db = getDb();
    const reportRef = db.collection("reports").doc();
    const createdAt = getNowDate();

    await db.runTransaction(async (tx) => {
      tx.set(reportRef, {
        reporterId,
        reportedId: data.reportedId.trim(),
        type,
        reason: data.reason.trim(),
        description: typeof data?.description === "string" ? data.description.trim() : null,
        status: "pending",
        reviewedBy: null,
        reviewedAt: null,
        resolutionNote: null,
        createdAt,
      });
    });

    return { reportId: reportRef.id };
  }

  async function reviewReport(data, context) {
    const actorId = assertAuthenticated(context, HttpsError);
    assertNonEmptyString(data?.reportId, "reportId", HttpsError);
    assertNonEmptyString(data?.status, "status", HttpsError);

    if (!ALLOWED_REVIEW_STATUSES.has(data.status)) {
      throw new HttpsError("invalid-argument", "Invalid review status.");
    }

    const db = getDb();
    const nowDate = getNowDate();
    const role = await resolveActorRole({
      db,
      actorId,
      context,
      HttpsError,
      createId,
      nowDate,
    });
    ensureAdminOrHigher(role, HttpsError);

    const reportRef = db.collection("reports").doc(data.reportId.trim());
    const logRef = db.collection("moderation_audit_logs").doc(createId());
    const reviewedAt = nowDate;
    const idempotencyKey = parseOptionalIdempotencyKey(data?.idempotencyKey);
    const idempotencyRef =
      idempotencyKey === null
        ? null
        : db
            .collection("command_idempotency")
            .doc(buildIdempotencyDocId(actorId, "review_report", reportRef.id, idempotencyKey));
    let deduplicated = false;

    await db.runTransaction(async (tx) => {
      if (idempotencyRef) {
        const idempotencyDoc = await tx.get(idempotencyRef);
        if (idempotencyDoc.exists) {
          deduplicated = true;
          return;
        }
      }

      const reportDoc = await tx.get(reportRef);
      if (!reportDoc.exists) {
        throw new HttpsError("not-found", "Report not found.");
      }

      tx.update(reportRef, {
        status: data.status,
        reviewedBy: actorId,
        reviewedAt,
        resolutionNote: typeof data?.resolutionNote === "string" ? data.resolutionNote.trim() : null,
      });

      tx.set(logRef, {
        actorId,
        action: "review_report",
        targetId: reportRef.id,
        reason: data.status,
        note: typeof data?.resolutionNote === "string" ? data.resolutionNote.trim() : null,
        timestamp: reviewedAt,
      });

      if (idempotencyRef) {
        tx.set(idempotencyRef, {
          actorId,
          action: "review_report",
          targetId: reportRef.id,
          timestamp: reviewedAt,
        });
      }
    });

    return { ok: true, deduplicated };
  }

  async function suspendUser(data, context) {
    const actorId = assertAuthenticated(context, HttpsError);
    assertNonEmptyString(data?.targetUserId, "targetUserId", HttpsError);
    assertNonEmptyString(data?.reason, "reason", HttpsError);

    const db = getDb();
    const nowDate = getNowDate();
    const role = await resolveActorRole({
      db,
      actorId,
      context,
      HttpsError,
      createId,
      nowDate,
    });
    ensureAdminOrHigher(role, HttpsError);

    const targetRef = db.collection("users").doc(data.targetUserId.trim());
    const logRef = db.collection("moderation_audit_logs").doc(createId());
    const timestamp = nowDate;
    const idempotencyKey = parseOptionalIdempotencyKey(data?.idempotencyKey);
    const idempotencyRef =
      idempotencyKey === null
        ? null
        : db
            .collection("command_idempotency")
            .doc(buildIdempotencyDocId(actorId, "suspend_user", targetRef.id, idempotencyKey));
    let deduplicated = false;

    await db.runTransaction(async (tx) => {
      if (idempotencyRef) {
        const idempotencyDoc = await tx.get(idempotencyRef);
        if (idempotencyDoc.exists) {
          deduplicated = true;
          return;
        }
      }

      const targetDoc = await tx.get(targetRef);
      if (!targetDoc.exists) {
        throw new HttpsError("not-found", "Target user not found.");
      }

      tx.update(targetRef, {
        status: "suspended",
        suspendedAt: timestamp,
        suspensionReason: data.reason.trim(),
        updatedByAdminId: actorId,
      });

      tx.set(logRef, {
        actorId,
        action: "suspend_user",
        targetId: targetRef.id,
        reason: data.reason.trim(),
        timestamp,
      });

      if (idempotencyRef) {
        tx.set(idempotencyRef, {
          actorId,
          action: "suspend_user",
          targetId: targetRef.id,
          timestamp,
        });
      }
    });

    return { ok: true, deduplicated };
  }

  async function unsuspendUser(data, context) {
    const actorId = assertAuthenticated(context, HttpsError);
    assertNonEmptyString(data?.targetUserId, "targetUserId", HttpsError);

    const db = getDb();
    const nowDate = getNowDate();
    const role = await resolveActorRole({
      db,
      actorId,
      context,
      HttpsError,
      createId,
      nowDate,
    });
    ensureAdminOrHigher(role, HttpsError);

    const targetRef = db.collection("users").doc(data.targetUserId.trim());
    const logRef = db.collection("moderation_audit_logs").doc(createId());
    const timestamp = nowDate;
    const idempotencyKey = parseOptionalIdempotencyKey(data?.idempotencyKey);
    const idempotencyRef =
      idempotencyKey === null
        ? null
        : db
            .collection("command_idempotency")
            .doc(buildIdempotencyDocId(actorId, "unsuspend_user", targetRef.id, idempotencyKey));
    let deduplicated = false;

    await db.runTransaction(async (tx) => {
      if (idempotencyRef) {
        const idempotencyDoc = await tx.get(idempotencyRef);
        if (idempotencyDoc.exists) {
          deduplicated = true;
          return;
        }
      }

      const targetDoc = await tx.get(targetRef);
      if (!targetDoc.exists) {
        throw new HttpsError("not-found", "Target user not found.");
      }

      tx.update(targetRef, {
        status: "active",
        suspendedAt: null,
        suspensionReason: null,
        updatedByAdminId: actorId,
      });

      tx.set(logRef, {
        actorId,
        action: "unsuspend_user",
        targetId: targetRef.id,
        timestamp,
      });

      if (idempotencyRef) {
        tx.set(idempotencyRef, {
          actorId,
          action: "unsuspend_user",
          targetId: targetRef.id,
          timestamp,
        });
      }
    });

    return { ok: true, deduplicated };
  }

  async function setUserRole(data, context) {
    const actorId = assertAuthenticated(context, HttpsError);
    assertNonEmptyString(data?.targetUserId, "targetUserId", HttpsError);
    assertNonEmptyString(data?.role, "role", HttpsError);

    const requestedRole = data.role.trim();
    if (!ALLOWED_ROLES.has(requestedRole)) {
      throw new HttpsError("invalid-argument", "Invalid role.");
    }

    const db = getDb();
    const nowDate = getNowDate();
    const actorRole = await resolveActorRole({
      db,
      actorId,
      context,
      HttpsError,
      createId,
      nowDate,
    });
    ensureAdminOrHigher(actorRole, HttpsError);

    const targetUserId = data.targetUserId.trim();
    if (actorId === targetUserId) {
      throw new HttpsError("failed-precondition", "Cannot change your own role.");
    }

    const targetRef = db.collection("users").doc(targetUserId);
    const logRef = db.collection("moderation_audit_logs").doc(createId());
    const timestamp = nowDate;
    const idempotencyKey = parseOptionalIdempotencyKey(data?.idempotencyKey);
    const idempotencyRef =
      idempotencyKey === null
        ? null
        : db
            .collection("command_idempotency")
            .doc(buildIdempotencyDocId(actorId, "set_user_role", targetRef.id, idempotencyKey));
    let deduplicated = false;

    await db.runTransaction(async (tx) => {
      if (idempotencyRef) {
        const idempotencyDoc = await tx.get(idempotencyRef);
        if (idempotencyDoc.exists) {
          deduplicated = true;
          return;
        }
      }

      const targetDoc = await tx.get(targetRef);
      if (!targetDoc.exists) {
        throw new HttpsError("not-found", "Target user not found.");
      }

      tx.update(targetRef, {
        role: requestedRole,
        updatedByAdminId: actorId,
      });

      tx.set(logRef, {
        actorId,
        action: "set_user_role",
        targetId: targetRef.id,
        reason: requestedRole,
        timestamp,
      });

      if (idempotencyRef) {
        tx.set(idempotencyRef, {
          actorId,
          action: "set_user_role",
          targetId: targetRef.id,
          timestamp,
        });
      }
    });

    return { ok: true, deduplicated };
  }

  return {
    createReport,
    reviewReport,
    suspendUser,
    unsuspendUser,
    setUserRole,
  };
}

module.exports = {
  buildAdminCommandHandlers,
};
