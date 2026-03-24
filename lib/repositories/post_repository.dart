import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/post_service.dart';

class PostRepository {
  final PostService _postService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PostRepository({PostService? postService})
    : _postService = postService ?? PostService();

  /// Create a new post with user info embedded
  Future<String> createPost({
    required UserModel user,
    required String content,
    String? imageUrl,
    List<String>? imageUrls,
    List<String>? videoUrls,
    List<String>? fileUrls,
    List<String>? tags,
    PostPrivacy privacy = PostPrivacy.public,
    PostStatus status = PostStatus.published,
  }) async {
    final normalizedImageUrls = (imageUrls ?? const <String>[])
        .where((url) => url.trim().isNotEmpty)
        .toList();
    final primaryImageUrl = normalizedImageUrls.isNotEmpty
        ? normalizedImageUrls.first
        : imageUrl;
    final normalizedVideoUrls = (videoUrls ?? const <String>[])
        .where((url) => url.trim().isNotEmpty)
        .toList();
    final normalizedFileUrls = (fileUrls ?? const <String>[])
        .where((url) => url.trim().isNotEmpty)
        .toList();
    final normalizedTags = (tags ?? const <String>[])
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final post = PostModel(
      id: '',
      userId: user.uid,
      userName: user.name,
      userUsername: user.username,
      userProfilePhoto: user.profilePhoto,
      content: content,
      imageUrl: primaryImageUrl,
      imageUrls: normalizedImageUrls,
      videoUrls: normalizedVideoUrls,
      fileUrls: normalizedFileUrls,
      tags: normalizedTags,
      privacy: privacy,
      status: status,
      createdAt: DateTime.now(),
    );
    return _postService.createPost(post);
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) =>
      _postService.updatePost(postId, data);

  Future<void> deletePost(String postId) => _postService.deletePost(postId);

  Future<PostModel?> getPostById(String postId) =>
      _postService.getPostById(postId);

  Stream<PostModel?> getPostStream(String postId) =>
      _postService.getPostStream(postId);

  /// Get feed posts with pagination support.
  /// Tries the fan-out feed first; falls back to the posts collection
  /// if the fan-out feed is empty (e.g. for pre-existing posts).
  Future<({List<PostModel> posts, DocumentSnapshot? lastDoc})> getFeedPosts({
    required String currentUserId,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    if (currentUserId.isEmpty) {
      final fallbackPosts = await _postService.getFeedPosts(
        lastDoc: lastDoc,
        limit: limit,
      );
      return (posts: fallbackPosts, lastDoc: null);
    }

    // Try fan-out feed first
    final snapshot = await _postService.getFeedPostsRaw(
      currentUserId: currentUserId,
      lastDoc: lastDoc,
      limit: limit,
    );

    if (snapshot.docs.isNotEmpty) {
      // Fan-out feed has data — resolve post pointers
      final List<PostModel> posts = [];
      for (var doc in snapshot.docs) {
        final postDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(doc.id)
            .get();
        if (postDoc.exists) {
          posts.add(
            PostModel.fromMap(
              postDoc.data() as Map<String, dynamic>,
              postDoc.id,
            ),
          );
        }
      }

      // Blend first-page fallback results so follower-only posts are visible
      // even if older fan-out data only contains public posts.
      if (lastDoc == null) {
        final fallbackPosts = await _getFollowerAwareFallbackFeedPosts(
          currentUserId: currentUserId,
          limit: limit,
        );
        final mergedById = <String, PostModel>{
          for (final post in posts) post.id: post,
          for (final post in fallbackPosts) post.id: post,
        };
        final mergedPosts = mergedById.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return (
          posts: mergedPosts.take(limit).toList(),
          lastDoc: snapshot.docs.last,
        );
      }

      return (posts: posts, lastDoc: snapshot.docs.last);
    }

    // Fallback: emulate fan-out feed for users who do not yet have feed pointers.
    final fallbackPosts = await _getFollowerAwareFallbackFeedPosts(
      currentUserId: currentUserId,
      limit: limit,
    );
    return (
      posts: fallbackPosts,
      lastDoc: null, // pagination handled by getFeedPosts internally
    );
  }

  Future<List<PostModel>> _getFollowerAwareFallbackFeedPosts({
    required String currentUserId,
    required int limit,
  }) async {
    // Always include global public posts so Home never collapses to only
    // self/following when fan-out pointers are sparse.
    final publicSnapshot = await _firestore
        .collection('posts')
        .where('status', isEqualTo: PostStatus.published.name)
        .where('privacy', isEqualTo: PostPrivacy.public.name)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final publicPosts = publicSnapshot.docs
        .map((doc) => PostModel.fromMap(doc.data(), doc.id))
        .toList();

    final followingSnap = await _firestore
        .collection('followers')
        .where('followerId', isEqualTo: currentUserId)
        .get();

    final authorIds = <String>{
      currentUserId,
      ...followingSnap.docs
          .map((doc) => (doc.data()['followingId'] as String?)?.trim() ?? '')
          .where((id) => id.isNotEmpty),
    }.toList();

    final List<PostModel> posts = [];
    for (int i = 0; i < authorIds.length; i += 10) {
      final chunk = authorIds.sublist(
        i,
        (i + 10 > authorIds.length) ? authorIds.length : i + 10,
      );

      final snapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: chunk)
          .where('status', isEqualTo: PostStatus.published.name)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      posts.addAll(
        snapshot.docs.map((doc) => PostModel.fromMap(doc.data(), doc.id)),
      );
    }

    final mergedById = <String, PostModel>{
      for (final post in publicPosts) post.id: post,
      for (final post in posts) post.id: post,
    };
    final merged =
        mergedById.values
            .where(
              (post) =>
                  post.privacy != PostPrivacy.onlyMe ||
                  post.userId == currentUserId,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged.take(limit).toList();
  }

  Future<List<PostModel>> getUserPosts({
    required String userId,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) =>
      _postService.getUserPosts(userId: userId, lastDoc: lastDoc, limit: limit);

  Future<List<PostModel>> getUserDrafts(String userId) =>
      _postService.getUserDrafts(userId);

  Future<List<PostModel>> getUserArchived(String userId) =>
      _postService.getUserArchived(userId);

  // --- Likes ---

  Future<void> likePost(String postId, String userId) =>
      _postService.likePost(postId, userId);

  Future<void> unlikePost(String postId, String userId) =>
      _postService.unlikePost(postId, userId);

  Future<bool> hasUserLikedPost(String postId, String userId) =>
      _postService.hasUserLikedPost(postId, userId);

  Stream<bool> userLikeStream(String postId, String userId) =>
      _postService.userLikeStream(postId, userId);

  Future<int> getLikesCount(String postId) =>
      _postService.getLikesCount(postId);

  Stream<int> likesCountStream(String postId) =>
      _postService.likesCountStream(postId);

  Future<int> getCommentsCount(String postId) =>
      _postService.getCommentsCount(postId);

  Stream<int> commentsCountStream(String postId) =>
      _postService.commentsCountStream(postId);

  Future<({int likesCount, int commentsCount})> getPostInteractionCounts(
    String postId,
  ) async {
    final counts = await Future.wait<int>([
      _postService.getLikesCount(postId),
      _postService.getCommentsCount(postId),
    ]);
    return (likesCount: counts[0], commentsCount: counts[1]);
  }

  // --- Comments ---

  Future<String> addComment({
    required String postId,
    required UserModel user,
    required String content,
  }) {
    final comment = CommentModel(
      id: '',
      postId: postId,
      userId: user.uid,
      userName: user.name,
      userUsername: user.username,
      userProfilePhoto: user.profilePhoto,
      content: content,
      createdAt: DateTime.now(),
    );
    return _postService.addComment(postId, comment);
  }

  Future<void> deleteComment(String postId, String commentId) =>
      _postService.deleteComment(postId, commentId);

  Stream<List<CommentModel>> getCommentsStream(String postId) =>
      _postService.getCommentsStream(postId);

  // --- Post Status ---

  Future<void> archivePost(String postId) =>
      _postService.updatePost(postId, {'status': PostStatus.archived.name});

  Future<void> unarchivePost(String postId) =>
      _postService.updatePost(postId, {'status': PostStatus.published.name});

  Future<void> saveDraft(String postId) =>
      _postService.updatePost(postId, {'status': PostStatus.draft.name});

  Future<void> publishDraft(String postId) =>
      _postService.updatePost(postId, {'status': PostStatus.published.name});
}
