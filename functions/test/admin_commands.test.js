const test = require("node:test");
const assert = require("node:assert/strict");

const { buildAdminCommandHandlers } = require("../admin_commands");

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function makeDocRef(collectionName, id, db) {
  return {
    id,
    path: `${collectionName}/${id}`,
    get: async () => {
      const data = db._store.get(`${collectionName}/${id}`);
      return {
        exists: data !== undefined,
        id,
        data: () => data,
      };
    },
    set: async (data) => {
      db._store.set(`${collectionName}/${id}`, data);
    },
    update: async (data) => {
      const current = db._store.get(`${collectionName}/${id}`) || {};
      db._store.set(`${collectionName}/${id}`, { ...current, ...data });
    },
  };
}

function makeFakeDb(seed = {}) {
  const store = new Map(Object.entries(seed));
  let idCounter = 0;
  return {
    _store: store,
    collection: (name) => ({
      doc: (id) =>
        makeDocRef(name, id || `${name}-auto-${++idCounter}`, {
          _store: store,
        }),
    }),
    runTransaction: async (callback) => {
      const tx = {
        get: async (docRef) => docRef.get(),
        set: (docRef, data) => {
          store.set(docRef.path, data);
        },
        update: (docRef, data) => {
          const current = store.get(docRef.path) || {};
          store.set(docRef.path, { ...current, ...data });
        },
      };
      return callback(tx);
    },
  };
}

function makeHandlers(seed = {}) {
  const fakeDb = makeFakeDb(seed);
  const handlers = buildAdminCommandHandlers({
    getDb: () => fakeDb,
    HttpsError: FakeHttpsError,
    nowIso: () => "2026-03-24T00:00:00.000Z",
    newId: () => "audit-log-id",
  });
  return { handlers, fakeDb };
}

test("createReport rejects unauthenticated callers", async () => {
  const { handlers } = makeHandlers();

  await assert.rejects(
    () =>
      handlers.createReport(
        {
          reportedId: "u2",
          type: "user",
          reason: "spam",
        },
        { auth: null },
      ),
    (error) => error && error.code === "unauthenticated",
  );
});

test("reviewReport requires admin role", async () => {
  const { handlers } = makeHandlers({
    "users/u1": { role: "user" },
    "reports/r1": { status: "pending" },
  });

  await assert.rejects(
    () =>
      handlers.reviewReport(
        {
          reportId: "r1",
          status: "reviewed",
        },
        { auth: { uid: "u1" } },
      ),
    (error) => error && error.code === "permission-denied",
  );
});

test("setUserRole requires admin role", async () => {
  const { handlers } = makeHandlers({
    "users/u1": { role: "user" },
    "users/u2": { role: "user" },
  });

  await assert.rejects(
    () =>
      handlers.setUserRole(
        {
          targetUserId: "u2",
          role: "admin",
        },
        { auth: { uid: "u1" } },
      ),
    (error) => error && error.code === "permission-denied",
  );
});

test("setUserRole rejects self role changes", async () => {
  const { handlers } = makeHandlers({
    "users/admin1": { role: "admin" },
  });

  await assert.rejects(
    () =>
      handlers.setUserRole(
        {
          targetUserId: "admin1",
          role: "user",
        },
        { auth: { uid: "admin1" } },
      ),
    (error) => error && error.code === "failed-precondition",
  );
});

test("suspendUser updates target user and creates audit log", async () => {
  const { handlers, fakeDb } = makeHandlers({
    "users/admin2": { role: "admin" },
    "users/u3": { role: "user", status: "active" },
  });

  await handlers.suspendUser(
    {
      targetUserId: "u3",
      reason: "abuse",
    },
    { auth: { uid: "admin2" } },
  );

  const userDoc = fakeDb._store.get("users/u3");
  assert.equal(userDoc.status, "suspended");
  assert.equal(userDoc.suspensionReason, "abuse");
  assert.equal(userDoc.updatedByAdminId, "admin2");
  assert.equal(userDoc.suspendedAt instanceof Date, true);

  const auditDoc = fakeDb._store.get("moderation_audit_logs/audit-log-id");
  assert.equal(auditDoc.action, "suspend_user");
  assert.equal(auditDoc.actorId, "admin2");
  assert.equal(auditDoc.targetId, "u3");
  assert.equal(auditDoc.timestamp instanceof Date, true);
});

test("fresh claims mismatch with Firestore role is rejected and logged", async () => {
  const { handlers, fakeDb } = makeHandlers({
    "users/admin3": { role: "admin" },
    "reports/r2": { status: "pending" },
  });

  await assert.rejects(
    () =>
      handlers.reviewReport(
        {
          reportId: "r2",
          status: "reviewed",
        },
        {
          auth: {
            uid: "admin3",
            token: {
              role: "user",
              roleIssuedAtMs: Date.parse("2026-03-24T00:00:00.000Z"),
            },
          },
        },
      ),
    (error) => error && error.code === "failed-precondition",
  );

  const mismatchLog = fakeDb._store.get("moderation_audit_logs/audit-log-id");
  assert.equal(mismatchLog.action, "auth_role_mismatch");
  assert.equal(mismatchLog.claimRole, "user");
  assert.equal(mismatchLog.firestoreRole, "admin");
  assert.equal(mismatchLog.timestamp instanceof Date, true);
});

test("expired claim falls back to Firestore role", async () => {
  const { handlers, fakeDb } = makeHandlers({
    "users/admin4": { role: "admin" },
    "users/u4": { role: "user", status: "active" },
  });

  await handlers.suspendUser(
    {
      targetUserId: "u4",
      reason: "abuse",
    },
    {
      auth: {
        uid: "admin4",
        token: {
          role: "user",
          roleIssuedAtMs: Date.parse("2026-03-23T23:58:00.000Z"),
        },
      },
    },
  );

  const userDoc = fakeDb._store.get("users/u4");
  assert.equal(userDoc.status, "suspended");
});

test("idempotency key prevents duplicate suspend side effects", async () => {
  const { handlers, fakeDb } = makeHandlers({
    "users/admin5": { role: "admin" },
    "users/u5": { role: "user", status: "active" },
  });

  await handlers.suspendUser(
    {
      targetUserId: "u5",
      reason: "abuse",
      idempotencyKey: "same-key",
    },
    { auth: { uid: "admin5" } },
  );

  await handlers.suspendUser(
    {
      targetUserId: "u5",
      reason: "abuse",
      idempotencyKey: "same-key",
    },
    { auth: { uid: "admin5" } },
  );

  const keys = Array.from(fakeDb._store.keys());
  const suspendLogs = keys.filter((k) => k.startsWith("moderation_audit_logs/")).length;
  assert.equal(suspendLogs, 1);
  assert.equal(
    fakeDb._store.get("command_idempotency/admin5_suspend_user_u5_same-key")
      .action,
    "suspend_user",
  );
});
