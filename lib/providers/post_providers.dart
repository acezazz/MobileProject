import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../repositories/post_repository.dart';
import '../services/post_service.dart';
import 'auth_providers.dart';

// Service & Repository
final postServiceProvider = Provider<PostService>((ref) => PostService());
final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(postService: ref.read(postServiceProvider));
});

// Feed notifier with pagination
final feedProvider =
    StateNotifierProvider<FeedNotifier, AsyncValue<List<PostModel>>>((ref) {
      return FeedNotifier(ref.read(postRepositoryProvider), ref);
    });

class FeedNotifier extends StateNotifier<AsyncValue<List<PostModel>>> {
  final PostRepository _repo;
  final Ref _ref;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isFetching = false;

  FeedNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadPosts();
  }

  bool get hasMore => _hasMore;

  Future<void> loadPosts() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final authUser = _ref.read(authStateProvider).valueOrNull;
      final result = await _repo.getFeedPosts(
        currentUserId: authUser?.uid ?? '',
        limit: 20,
      );
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length >= 20;
      state = AsyncValue.data(result.posts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    _isFetching = false;
  }

  Future<void> loadMore() async {
    if (_isFetching || !_hasMore) return;
    _isFetching = true;
    try {
      final authUser = _ref.read(authStateProvider).valueOrNull;
      final result = await _repo.getFeedPosts(
        currentUserId: authUser?.uid ?? '',
        lastDoc: _lastDoc,
        limit: 20,
      );
      _lastDoc = result.lastDoc;
      _hasMore = result.posts.length >= 20;
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, ...result.posts]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    _isFetching = false;
  }

  Future<void> refresh() async {
    _lastDoc = null;
    _hasMore = true;
    state = const AsyncValue.loading();
    await loadPosts();
  }
}

// User posts provider
final userPostsProvider = FutureProvider.family<List<PostModel>, String>((
  ref,
  userId,
) {
  return ref.read(postRepositoryProvider).getUserPosts(userId: userId);
});

final userArchivedPostsProvider =
    FutureProvider.family<List<PostModel>, String>((ref, userId) {
      return ref.read(postRepositoryProvider).getUserArchived(userId);
    });

// Single post stream
final postStreamProvider = StreamProvider.family<PostModel?, String>((
  ref,
  postId,
) {
  return ref.read(postRepositoryProvider).getPostStream(postId);
});

// Like status stream
final likeStatusProvider =
    StreamProvider.family<bool, ({String postId, String userId})>((ref, args) {
      return ref
          .read(postRepositoryProvider)
          .userLikeStream(args.postId, args.userId);
    });

// Comments stream
final commentsProvider = StreamProvider.family<List<CommentModel>, String>((
  ref,
  postId,
) {
  return ref.read(postRepositoryProvider).getCommentsStream(postId);
});

final postLikesCountProvider = StreamProvider.family<int, String>((
  ref,
  postId,
) {
  return ref.read(postRepositoryProvider).likesCountStream(postId);
});

final postCommentsCountProvider = StreamProvider.family<int, String>((
  ref,
  postId,
) {
  return ref.read(postRepositoryProvider).commentsCountStream(postId);
});

// Create post notifier
final createPostProvider =
    StateNotifierProvider<CreatePostNotifier, AsyncValue<void>>((ref) {
      return CreatePostNotifier(ref.read(postRepositoryProvider), ref);
    });

class CreatePostNotifier extends StateNotifier<AsyncValue<void>> {
  final PostRepository _repo;
  final Ref _ref;

  CreatePostNotifier(this._repo, this._ref)
    : super(const AsyncValue.data(null));

  Future<bool> createPost({
    required String content,
    String? imageUrl,
    List<String>? imageUrls,
    List<String>? videoUrls,
    List<String>? fileUrls,
    List<String>? tags,
    PostPrivacy privacy = PostPrivacy.public,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _ref.read(currentUserProfileProvider.future);
      if (user == null) throw Exception('Not logged in');
      await _repo.createPost(
        user: user,
        content: content,
        imageUrl: imageUrl,
        imageUrls: imageUrls,
        videoUrls: videoUrls,
        fileUrls: fileUrls,
        tags: tags,
        privacy: privacy,
      );
      state = const AsyncValue.data(null);
      // Refresh feed
      _ref.read(feedProvider.notifier).refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
