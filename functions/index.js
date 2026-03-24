const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { buildAdminCommandHandlers } = require("./admin_commands");
admin.initializeApp();

const adminCommandHandlers = buildAdminCommandHandlers({
  getDb: () => admin.firestore(),
  HttpsError: functions.https.HttpsError,
});

exports.createReport = functions.https.onCall((data, context) =>
  adminCommandHandlers.createReport(data, context)
);

exports.reviewReport = functions.https.onCall((data, context) =>
  adminCommandHandlers.reviewReport(data, context)
);

exports.suspendUser = functions.https.onCall((data, context) =>
  adminCommandHandlers.suspendUser(data, context)
);

exports.unsuspendUser = functions.https.onCall((data, context) =>
  adminCommandHandlers.unsuspendUser(data, context)
);

exports.setUserRole = functions.https.onCall((data, context) =>
  adminCommandHandlers.setUserRole(data, context)
);

// 1. Sync denormalized user data (name, username, photo) to posts and comments
exports.onUserUpdate = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    if (before.name === after.name && 
        before.username === after.username && 
        before.profilePhoto === after.profilePhoto) {
      return null;
    }

    const userId = context.params.userId;
    const db = admin.firestore();
    const batch = db.batch();

    // Update posts
    const postsSnapshot = await db.collection("posts").where("userId", "==", userId).get();
    postsSnapshot.forEach(doc => {
      batch.update(doc.ref, {
        userName: after.name,
        userUsername: after.username,
        userProfilePhoto: after.profilePhoto
      });
    });

    // Update comments
    const commentsSnapshot = await db.collectionGroup("comments").where("userId", "==", userId).get();
    commentsSnapshot.forEach(doc => {
      batch.update(doc.ref, {
        userName: after.name,
        userUsername: after.username,
        userProfilePhoto: after.profilePhoto
      });
    });

    return batch.commit();
  });

// 2. Safe counter increments (Likes)
exports.onLikeCreated = functions.firestore
  .document("posts/{postId}/likes/{userId}")
  .onCreate((snap, context) => {
    return admin.firestore().collection("posts").doc(context.params.postId).update({
      likesCount: admin.firestore.FieldValue.increment(1)
    });
  });

exports.onLikeDeleted = functions.firestore
  .document("posts/{postId}/likes/{userId}")
  .onDelete((snap, context) => {
    return admin.firestore().collection("posts").doc(context.params.postId).update({
      likesCount: admin.firestore.FieldValue.increment(-1)
    });
  });

// 3. Safe counter increments (Comments)
exports.onCommentCreated = functions.firestore
  .document("posts/{postId}/comments/{commentId}")
  .onCreate((snap, context) => {
    return admin.firestore().collection("posts").doc(context.params.postId).update({
      commentsCount: admin.firestore.FieldValue.increment(1)
    });
  });

exports.onCommentDeleted = functions.firestore
  .document("posts/{postId}/comments/{commentId}")
  .onDelete((snap, context) => {
    return admin.firestore().collection("posts").doc(context.params.postId).update({
      commentsCount: admin.firestore.FieldValue.increment(-1)
    });
  });

// 4. Safe counter increments (Followers)
exports.onFollowCreated = functions.firestore
  .document("followers/{followId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const db = admin.firestore();
    const batch = db.batch();
    
    batch.update(db.collection("users").doc(data.followerId), {
      followingCount: admin.firestore.FieldValue.increment(1)
    });
    batch.update(db.collection("users").doc(data.followingId), {
      followersCount: admin.firestore.FieldValue.increment(1)
    });
    
    return batch.commit();
  });

exports.onFollowDeleted = functions.firestore
  .document("followers/{followId}")
  .onDelete(async (snap, context) => {
    const data = snap.data();
    const db = admin.firestore();
    const batch = db.batch();
    
    batch.update(db.collection("users").doc(data.followerId), {
      followingCount: admin.firestore.FieldValue.increment(-1)
    });
    batch.update(db.collection("users").doc(data.followingId), {
      followersCount: admin.firestore.FieldValue.increment(-1)
    });
    
    return batch.commit();
  });

// 5. Generate secure Cloudinary upload signature
exports.generateUploadSignature = functions.https.onCall((data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
  }
  
  const timestamp = Math.round(new Date().getTime() / 1000);
  // Expect these from process.env set via firebase functions:secrets:set
  const apiSecret = process.env.CLOUDINARY_API_SECRET; 
  if (!apiSecret) return { error: "API Secret not configured on Server" };
  
  const str = `folder=archives/posts&timestamp=${timestamp}${apiSecret}`;
  const signature = crypto.createHash("sha1").update(str).digest("hex");
  
  return {
    timestamp,
    signature,
    folder: "archives/posts",
  };
});

// 6. Fan-out feed on new post
exports.onPostCreated = functions.firestore
  .document("posts/{postId}")
  .onCreate(async (snap, context) => {
    const postData = snap.data();
    if (postData.status !== "published") return null;
    if (postData.privacy !== "public" && postData.privacy !== "followersOnly") {
      return null;
    }
    
    const authorId = postData.userId;
    const db = admin.firestore();
    
    // Get all followers
    const followersSnap = await db.collection("followers").where("followingId", "==", authorId).get();
    
    // Also add to the author's own feed
    const batchArray = [];
    batchArray.push(db.batch());
    let operationCounter = 0;
    let batchIndex = 0;
    
    function commitToBatch(ref, data) {
        batchArray[batchIndex].set(ref, data);
        operationCounter++;
        if (operationCounter === 490) {
            batchArray.push(db.batch());
            batchIndex++;
            operationCounter = 0;
        }
    }
    
    const feedPtr = {
        postId: context.params.postId,
        authorId: authorId,
        createdAt: postData.createdAt
    };
    
    // Write to author's feed
    const authorFeedRef = db.collection("feeds").doc(authorId).collection("user_feed").doc(context.params.postId);
    commitToBatch(authorFeedRef, feedPtr);
    
    followersSnap.forEach(doc => {
        const followerId = doc.data().followerId;
        const feedRef = db.collection("feeds").doc(followerId).collection("user_feed").doc(context.params.postId);
        commitToBatch(feedRef, feedPtr);
    });
    
    const promises = batchArray.map(b => b.commit());
    return Promise.all(promises);
  });

// 7. One-time backfill for counters (likes/comments/followers/following)
exports.backfillCounters = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
  }

  const db = admin.firestore();
  const postsSnap = await db.collection("posts").get();
  const usersSnap = await db.collection("users").get();

  let batch = db.batch();
  let opCount = 0;
  let batchCommits = [];

  const queueUpdate = (ref, payload) => {
    batch.set(ref, payload, { merge: true });
    opCount++;
    if (opCount >= 450) {
      batchCommits.push(batch.commit());
      batch = db.batch();
      opCount = 0;
    }
  };

  for (const postDoc of postsSnap.docs) {
    const [likesSnap, commentsSnap] = await Promise.all([
      postDoc.ref.collection("likes").get(),
      postDoc.ref.collection("comments").get(),
    ]);

    queueUpdate(postDoc.ref, {
      likesCount: likesSnap.size,
      commentsCount: commentsSnap.size,
    });
  }

  const followersSnap = await db.collection("followers").get();
  const followersByTarget = new Map();
  const followingBySource = new Map();

  followersSnap.forEach((doc) => {
    const item = doc.data();
    const followerId = item.followerId;
    const followingId = item.followingId;

    followersByTarget.set(
      followingId,
      (followersByTarget.get(followingId) || 0) + 1
    );
    followingBySource.set(
      followerId,
      (followingBySource.get(followerId) || 0) + 1
    );
  });

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    queueUpdate(userDoc.ref, {
      followersCount: followersByTarget.get(uid) || 0,
      followingCount: followingBySource.get(uid) || 0,
    });
  }

  if (opCount > 0) {
    batchCommits.push(batch.commit());
  }

  await Promise.all(batchCommits);

  return {
    postsUpdated: postsSnap.size,
    usersUpdated: usersSnap.size,
    followersProcessed: followersSnap.size,
  };
});
