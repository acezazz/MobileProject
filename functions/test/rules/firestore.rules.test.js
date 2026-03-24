const fs = require('fs');
const path = require('path');
const { test, before, after, beforeEach } = require('node:test');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  setDoc,
  updateDoc,
  getDoc,
  serverTimestamp,
  Timestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'archives-rules-test';
const rulesPath = path.resolve(__dirname, '..', '..', '..', 'firestore.rules');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function adminUserDoc(uid) {
  return {
    role: 'admin',
    isSuspended: false,
    suspensionType: 'none',
    suspensionUntil: null,
    warningsCount: 0,
    strikesCount: 0,
    updatedAt: Timestamp.fromDate(new Date('2026-03-24T00:00:00Z')),
    updatedByAdminId: uid,
    status: 'active',
  };
}

function normalUserDoc() {
  return {
    role: 'user',
    isSuspended: false,
    suspensionType: 'none',
    suspensionUntil: null,
    warningsCount: 0,
    strikesCount: 0,
    updatedAt: Timestamp.fromDate(new Date('2026-03-24T00:00:00Z')),
    updatedByAdminId: null,
    name: 'User',
    username: 'user',
    status: 'active',
  };
}

async function seedDoc(collectionName, id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), collectionName, id), data);
  });
}

test('users: regular user can update safe profile fields only', async () => {
  const uid = 'user-safe';
  await seedDoc('users', uid, normalUserDoc());

  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'users', uid), {
      bio: 'Updated bio',
    })
  );
});

test('users: non-admin cannot update moderation fields', async () => {
  const uid = 'user-no-admin';
  await seedDoc('users', uid, normalUserDoc());

  const db = testEnv.authenticatedContext(uid).firestore();
  await assertFails(
    updateDoc(doc(db, 'users', uid), {
      strikesCount: 2,
      updatedAt: serverTimestamp(),
      updatedByAdminId: uid,
    })
  );
});

test('users: admin can update moderation fields with valid suspension payload', async () => {
  const adminUid = 'admin-1';
  const targetUid = 'user-target';

  await seedDoc('users', adminUid, adminUserDoc(adminUid));
  await seedDoc('users', targetUid, normalUserDoc());

  const db = testEnv.authenticatedContext(adminUid).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'users', targetUid), {
      isSuspended: true,
      suspensionType: 'temporary',
      suspensionUntil: Timestamp.fromDate(new Date('2026-04-01T00:00:00Z')),
      warningsCount: 1,
      strikesCount: 1,
      updatedAt: serverTimestamp(),
      updatedByAdminId: adminUid,
    })
  );
});

test('users: admin cannot change own role', async () => {
  const adminUid = 'admin-self';

  await seedDoc('users', adminUid, adminUserDoc(adminUid));

  const db = testEnv.authenticatedContext(adminUid).firestore();
  await assertFails(
    updateDoc(doc(db, 'users', adminUid), {
      role: 'user',
      updatedAt: serverTimestamp(),
      updatedByAdminId: adminUid,
    })
  );
});

test('reports: authenticated user can create open report', async () => {
  const reporterUid = 'reporter-1';

  const db = testEnv.authenticatedContext(reporterUid).firestore();
  await assertSucceeds(
    setDoc(doc(db, 'reports', 'report-1'), {
      reporterId: reporterUid,
      targetType: 'post',
      targetId: 'post-9',
      reason: 'spam',
      detail: 'Repeated scam links',
      status: 'open',
      reviewedBy: null,
      reviewedAt: null,
      resolutionNote: null,
      createdAt: serverTimestamp(),
    })
  );
});

test('reports: non-admin cannot move report status', async () => {
  const reporterUid = 'reporter-2';

  await seedDoc('reports', 'report-2', {
    reporterId: reporterUid,
    targetType: 'post',
    targetId: 'post-2',
    reason: 'harassment',
    detail: 'Abusive language',
    status: 'open',
    reviewedBy: null,
    reviewedAt: null,
    resolutionNote: null,
    createdAt: Timestamp.fromDate(new Date('2026-03-24T00:00:00Z')),
  });

  const db = testEnv.authenticatedContext(reporterUid).firestore();
  await assertFails(
    updateDoc(doc(db, 'reports', 'report-2'), {
      status: 'under_review',
      reviewedBy: reporterUid,
      reviewedAt: serverTimestamp(),
      resolutionNote: null,
    })
  );
});

test('reports: admin can perform valid transitions only', async () => {
  const adminUid = 'admin-report';

  await seedDoc('users', adminUid, adminUserDoc(adminUid));
  await seedDoc('reports', 'report-3', {
    reporterId: 'reporter-3',
    targetType: 'comment',
    targetId: 'comment-4',
    reason: 'hate',
    detail: 'Offensive words',
    status: 'open',
    reviewedBy: null,
    reviewedAt: null,
    resolutionNote: null,
    createdAt: Timestamp.fromDate(new Date('2026-03-24T00:00:00Z')),
  });

  const db = testEnv.authenticatedContext(adminUid).firestore();
  await assertSucceeds(
    updateDoc(doc(db, 'reports', 'report-3'), {
      status: 'under_review',
      reviewedBy: adminUid,
      reviewedAt: serverTimestamp(),
      resolutionNote: null,
    })
  );

  await assertSucceeds(
    updateDoc(doc(db, 'reports', 'report-3'), {
      status: 'resolved',
      reviewedBy: adminUid,
      reviewedAt: serverTimestamp(),
      resolutionNote: 'Action taken',
    })
  );
});

test('reports: invalid transition open -> resolved is denied', async () => {
  const adminUid = 'admin-invalid-transition';

  await seedDoc('users', adminUid, adminUserDoc(adminUid));
  await seedDoc('reports', 'report-4', {
    reporterId: 'reporter-4',
    targetType: 'user',
    targetId: 'user-9',
    reason: 'impersonation',
    detail: 'Pretending to be someone else',
    status: 'open',
    reviewedBy: null,
    reviewedAt: null,
    resolutionNote: null,
    createdAt: Timestamp.fromDate(new Date('2026-03-24T00:00:00Z')),
  });

  const db = testEnv.authenticatedContext(adminUid).firestore();
  await assertFails(
    updateDoc(doc(db, 'reports', 'report-4'), {
      status: 'resolved',
      reviewedBy: adminUid,
      reviewedAt: serverTimestamp(),
      resolutionNote: 'Skipped triage',
    })
  );
});

test('moderation_audit_logs: admin read allowed and client writes denied', async () => {
  const adminUid = 'admin-audit';
  const userUid = 'user-audit';

  await seedDoc('users', adminUid, adminUserDoc(adminUid));
  await seedDoc('users', userUid, normalUserDoc());
  await seedDoc('moderation_audit_logs', 'log-1', {
    actionType: 'suspend_user',
    actorId: adminUid,
    targetType: 'user',
    targetId: userUid,
    before: { isSuspended: false },
    after: { isSuspended: true },
    reason: 'policy violation',
    createdAt: Timestamp.fromDate(new Date('2026-03-24T00:00:00Z')),
  });

  const adminDb = testEnv.authenticatedContext(adminUid).firestore();
  const userDb = testEnv.authenticatedContext(userUid).firestore();

  await assertSucceeds(getDoc(doc(adminDb, 'moderation_audit_logs', 'log-1')));
  await assertFails(getDoc(doc(userDb, 'moderation_audit_logs', 'log-1')));
  await assertFails(
    setDoc(doc(adminDb, 'moderation_audit_logs', 'log-2'), {
      actionType: 'warn_user',
      actorId: adminUid,
      targetType: 'user',
      targetId: userUid,
      before: {},
      after: { warningsCount: 1 },
      reason: 'warning',
      createdAt: serverTimestamp(),
    })
  );
});
