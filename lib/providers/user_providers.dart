import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/role_constants.dart';
import '../core/utils/role_utils.dart';
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

final isAdminOrHigherProvider = Provider<bool>((ref) {
  return isAdminOrHigher(ref.watch(currentUserRoleProvider));
});

final adminUsersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.read(userRepositoryProvider).getRecentUsers(limit: 50);
});

final adminUserActionProvider =
    StateNotifierProvider<AdminUserActionNotifier, AsyncValue<void>>((ref) {
      return AdminUserActionNotifier(ref.read(userRepositoryProvider));
    });

class AdminUserActionNotifier extends StateNotifier<AsyncValue<void>> {
  final UserRepository _repo;

  AdminUserActionNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<bool> suspendUser({
    required String targetUserId,
    required String actorAdminId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.suspendUser(
        targetUserId: targetUserId,
        actorAdminId: actorAdminId,
        reason: reason,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> unsuspendUser({
    required String targetUserId,
    required String actorAdminId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.unsuspendUser(
        targetUserId: targetUserId,
        actorAdminId: actorAdminId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> setRole({
    required String targetUserId,
    required String actorAdminId,
    required String role,
  }) async {
    if (role != RoleConstants.user && role != RoleConstants.admin) {
      return false;
    }

    state = const AsyncValue.loading();
    try {
      await _repo.setUserRole(
        targetUserId: targetUserId,
        role: role,
        actorAdminId: actorAdminId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateAccount({
    required String targetUserId,
    required String actorAdminId,
    required bool isSuspended,
    required String suspensionType,
    DateTime? suspensionUntil,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateAdminUserAccount(
        targetUserId: targetUserId,
        actorAdminId: actorAdminId,
        isSuspended: isSuspended,
        suspensionType: suspensionType,
        suspensionUntil: suspensionUntil,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
