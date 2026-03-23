import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/follower_model.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'auth_providers.dart';

// Repository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(userService: ref.read(userServiceProvider));
});

// View another user's profile
final userProfileProvider = FutureProvider.family<UserModel?, String>((
  ref,
  userId,
) {
  return ref.read(userRepositoryProvider).getUserById(userId);
});

// User profile stream (real-time)
final userProfileStreamProvider = StreamProvider.family<UserModel?, String>((
  ref,
  userId,
) {
  return ref.read(userRepositoryProvider).getUserStream(userId);
});

// Follow status stream
final isFollowingProvider =
    StreamProvider.family<bool, ({String currentUserId, String targetUserId})>((
      ref,
      args,
    ) {
      return ref
          .read(userRepositoryProvider)
          .isFollowingStream(args.currentUserId, args.targetUserId);
    });

// Followers list
final followersListProvider =
    FutureProvider.family<List<FollowerModel>, String>((ref, userId) {
      return ref.read(userRepositoryProvider).getFollowers(userId);
    });

// Following list
final followingListProvider =
    FutureProvider.family<List<FollowerModel>, String>((ref, userId) {
      return ref.read(userRepositoryProvider).getFollowing(userId);
    });

final followersCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  return ref.read(userRepositoryProvider).followersCountStream(userId);
});

final followingCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  return ref.read(userRepositoryProvider).followingCountStream(userId);
});

// Search users
final searchUsersProvider = FutureProvider.family<List<UserModel>, String>((
  ref,
  query,
) {
  if (query.trim().isEmpty) return Future.value([]);
  return ref.read(userRepositoryProvider).searchUsers(query.trim());
});

final excludeFollowedRecommendationsProvider = StateProvider<bool>((ref) {
  return false;
});

final recommendedUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final currentUser = ref.watch(authStateProvider).valueOrNull;
  if (currentUser == null) return [];

  final excludeFollowed = ref.watch(excludeFollowedRecommendationsProvider);
  return ref
      .read(userRepositoryProvider)
      .getRecommendedUsers(
        currentUserId: currentUser.uid,
        excludeFollowed: excludeFollowed,
      );
});
