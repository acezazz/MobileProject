import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _postsRef =>
      _firestore.collection(FirestoreConstants.postsCollection);

  // --- Posts ---

  Future<String> createPost(PostModel post) async {
    final docRef = await _postsRef.add(post.toMap());
    return docRef.id;
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    await _postsRef.doc(postId).update(data);
  }

  Future<void> deletePost(String postId) async {
    await _postsRef.doc(postId).delete();
  }

  Future<PostModel?> getPostById(String postId) async {
    final doc = await _postsRef.doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<PostModel?> getPostStream(String postId) {
    return _postsRef.doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  /// Get public feed posts (paginated)
  Future<List<PostModel>> getFeedPosts({
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query query = _postsRef
        .where('status', isEqualTo: PostStatus.published.name)
        .where('privacy', isEqualTo: PostPrivacy.public.name)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  /// Get posts by a specific user (paginated)
  Future<List<PostModel>> getUserPosts({
    required String userId,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query query = _postsRef
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: PostStatus.published.name)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  /// Get user's draft posts
  Future<List<PostModel>> getUserDrafts(String userId) async {
    final snapshot = await _postsRef
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: PostStatus.draft.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  /// Get user's archived posts
  Future<List<PostModel>> getUserArchived(String userId) async {
    final snapshot = await _postsRef
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: PostStatus.archived.name)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  // --- Likes ---

  Future<void> likePost(String postId, String userId) async {
    final batch = _firestore.batch();

    // Add like subdocument
    batch.set(
      _postsRef
          .doc(postId)
          .collection(FirestoreConstants.likesSubcollection)
          .doc(userId),
      {'userId': userId, 'createdAt': Timestamp.now()},
    );

    // Likes count is now managed by Firebase Cloud Functions.

    await batch.commit();
  }

  Future<void> unlikePost(String postId, String userId) async {
    final batch = _firestore.batch();

    batch.delete(
      _postsRef
          .doc(postId)
          .collection(FirestoreConstants.likesSubcollection)
          .doc(userId),
    );

    // Likes count is now managed by Firebase Cloud Functions.

    await batch.commit();
  }

  Future<bool> hasUserLikedPost(String postId, String userId) async {
    final doc = await _postsRef
        .doc(postId)
        .collection(FirestoreConstants.likesSubcollection)
        .doc(userId)
        .get();
    return doc.exists;
  }

  Stream<bool> userLikeStream(String postId, String userId) {
    return _postsRef
        .doc(postId)
        .collection(FirestoreConstants.likesSubcollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<int> getLikesCount(String postId) async {
    final snapshot = await _postsRef
        .doc(postId)
        .collection(FirestoreConstants.likesSubcollection)
        .get();
    return snapshot.size;
  }

  Stream<int> likesCountStream(String postId) {
    return _postsRef
        .doc(postId)
        .collection(FirestoreConstants.likesSubcollection)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  // --- Comments ---

  Future<String> addComment(String postId, CommentModel comment) async {
    final batch = _firestore.batch();

    final commentRef = _postsRef
        .doc(postId)
        .collection(FirestoreConstants.commentsSubcollection)
        .doc();

    batch.set(commentRef, comment.toMap());

    // Comments count is now managed by Firebase Cloud Functions.

    await batch.commit();
    return commentRef.id;
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final batch = _firestore.batch();

    batch.delete(
      _postsRef
          .doc(postId)
          .collection(FirestoreConstants.commentsSubcollection)
          .doc(commentId),
    );

    // Comments count is now managed by Firebase Cloud Functions.

    await batch.commit();
  }

  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _postsRef
        .doc(postId)
        .collection(FirestoreConstants.commentsSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<int> getCommentsCount(String postId) async {
    final snapshot = await _postsRef
        .doc(postId)
        .collection(FirestoreConstants.commentsSubcollection)
        .get();
    return snapshot.size;
  }

  Stream<int> commentsCountStream(String postId) {
    return _postsRef
        .doc(postId)
        .collection(FirestoreConstants.commentsSubcollection)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Get the raw QuerySnapshot for pagination support via pointers
  Future<QuerySnapshot> getFeedPostsRaw({
    required String currentUserId,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query query = _firestore
        .collection('feeds')
        .doc(currentUserId)
        .collection('user_feed')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    return query.get();
  }
}
