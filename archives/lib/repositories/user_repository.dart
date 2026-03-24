import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../models/follower_model.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserRepository {
  final UserService _userService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserRepository({UserService? userService})
    : _userService = userService ?? UserService();

  CollectionReference get _followersRef =>
      _firestore.collection(FirestoreConstants.followersCollection);

  // --- Profile ---

  Future<UserModel?> getUserById(String uid) => _userService.getUserById(uid);

  Stream<UserModel?> getUserStream(String uid) =>
      _userService.getUserStream(uid);

  Future<void> updateProfile(String uid, Map<String, dynamic> data) =>
      _userService.updateUserProfile(uid, data);

  Future<List<UserModel>> searchUsers(String query) => _userService
      .searchUsers(query)
      .then((users) => users.where((user) => user.role != 'admin').toList());

  Future<List<UserModel>> getRecentUsers({int limit = 50}) =>
      _userService.getRecentUsers(limit: limit);

  Future<List<UserModel>> getRecommendedUsers({
    required String currentUserId,
    bool excludeFollowed = false,
    int limit = 20,
  }) async {
    final users = await _userService.getTopUsersByFollowers(limit: limit * 3);
    Set<String> followedIds = <String>{};

    if (excludeFollowed) {
      final following = await getFollowing(currentUserId);
      followedIds = following.map((item) => item.followingId).toSet();
    }

    return users
        .where((user) => user.uid != currentUserId)
        .where((user) => user.role != 'admin')
        .where((user) => !excludeFollowed || !followedIds.contains(user.uid))
        .take(limit)
        .toList();
  }

  Future<Map<String, dynamic>> _loadModerationSnapshot(
    String targetUserId,
  ) async {
    final doc = await _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(targetUserId)
        .get();

    if (!doc.exists) {
      throw StateError('User not found');
    }

    return doc.data() ?? <String, dynamic>{};
  }

  Map<String, dynamic> _buildModerationPatch({
    required Map<String, dynamic> current,
    required String actorAdminId,
    String? role,
    bool? isSuspended,
    String? suspensionType,
    DateTime? suspensionUntil,
    int? warningsCount,
    int? strikesCount,
  }) {
    final currentIsSuspended =
        current['isSuspended'] == true ||
        (current['status']?.toString().toLowerCase() == 'suspended');

    final normalizedSuspensionType =
        suspensionType ??
        (() {
          final raw = current['suspensionType']?.toString();
          if (raw == 'none' || raw == 'temporary' || raw == 'permanent') {
            return raw;
          }
          return currentIsSuspended ? 'permanent' : 'none';
        }());

    final normalizedWarningsCount =
        warningsCount ??
        (current['warningsCount'] is int ? current['warningsCount'] as int : 0);
    final normalizedStrikesCount =
        strikesCount ??
        (current['strikesCount'] is int ? current['strikesCount'] as int : 0);

    final normalizedRole =
        role ??
        (current['role']?.toString().isNotEmpty == true
            ? current['role'].toString()
            : 'user');
    final normalizedIsSuspended = isSuspended ?? currentIsSuspended;

    return {
      'role': normalizedRole,
      'isSuspended': normalizedIsSuspended,
      'suspensionType': normalizedSuspensionType,
      'suspensionUntil': suspensionUntil == null
          ? null
          : Timestamp.fromDate(suspensionUntil),
      'warningsCount': normalizedWarningsCount,
      'strikesCount': normalizedStrikesCount,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByAdminId': actorAdminId,
    };
  }

  // --- Follow System ---

  /// Follow a user. Creates follower doc. Counters updated by Cloud Functions.
  Future<void> followUser(String currentUserId, String targetUserId) async {
    final docId = '${currentUserId}_$targetUserId';
    final batch = _firestore.batch();

    // Create follower document
    batch.set(
      _followersRef.doc(docId),
      FollowerModel(
        id: docId,
        followerId: currentUserId,
        followingId: targetUserId,
        createdAt: DateTime.now(),
      ).toMap(),
    );

    await batch.commit();
  }

  /// Unfollow a user. Deletes follower doc. Counters updated by Cloud Functions.
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final docId = '${currentUserId}_$targetUserId';
    final batch = _firestore.batch();

    batch.delete(_followersRef.doc(docId));

    await batch.commit();
  }

  /// Check if current user follows target user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final docId = '${currentUserId}_$targetUserId';
    final doc = await _followersRef.doc(docId).get();
    return doc.exists;
  }

  /// Real-time stream of follow status
  Stream<bool> isFollowingStream(String currentUserId, String targetUserId) {
    final docId = '${currentUserId}_$targetUserId';
    return _followersRef.doc(docId).snapshots().map((doc) => doc.exists);
  }

  /// Get list of followers for a user
  Future<List<FollowerModel>> getFollowers(String userId) async {
    final snapshot = await _followersRef
        .where('followingId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              FollowerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  /// Get list of users that a user is following
  Future<List<FollowerModel>> getFollowing(String userId) async {
    final snapshot = await _followersRef
        .where('followerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              FollowerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<int> getFollowersCount(String userId) =>
      _userService.getFollowersCount(userId);

  Stream<int> followersCountStream(String userId) =>
      _userService.followersCountStream(userId);

  Future<int> getFollowingCount(String userId) =>
      _userService.getFollowingCount(userId);

  Stream<int> followingCountStream(String userId) =>
      _userService.followingCountStream(userId);

  Future<void> suspendUser({
    required String targetUserId,
    required String actorAdminId,
    required String reason,
  }) async {
    final current = await _loadModerationSnapshot(targetUserId);
    final hasTemporaryUntil = current['suspensionUntil'] is Timestamp;

    await _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(targetUserId)
        .update(
          _buildModerationPatch(
            current: current,
            actorAdminId: actorAdminId,
            isSuspended: true,
            suspensionType: hasTemporaryUntil ? 'temporary' : 'permanent',
            suspensionUntil: hasTemporaryUntil
                ? (current['suspensionUntil'] as Timestamp).toDate()
                : null,
          ),
        );
  }

  Future<void> unsuspendUser({
    required String targetUserId,
    required String actorAdminId,
  }) async {
    final current = await _loadModerationSnapshot(targetUserId);

    await _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(targetUserId)
        .update(
          _buildModerationPatch(
            current: current,
            actorAdminId: actorAdminId,
            isSuspended: false,
            suspensionType: 'none',
            suspensionUntil: null,
          ),
        );
  }

  Future<void> setUserRole({
    required String targetUserId,
    required String role,
    required String actorAdminId,
  }) async {
    if (targetUserId == actorAdminId) {
      throw StateError('Admins cannot change their own role.');
    }

    final current = await _loadModerationSnapshot(targetUserId);

    await _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(targetUserId)
        .update(
          _buildModerationPatch(
            current: current,
            actorAdminId: actorAdminId,
            role: role,
          ),
        );
  }

  Future<void> updateAdminUserAccount({
    required String targetUserId,
    required String actorAdminId,
    required bool isSuspended,
    required String suspensionType,
    DateTime? suspensionUntil,
  }) async {
    final current = await _loadModerationSnapshot(targetUserId);

    await _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(targetUserId)
        .update(
          _buildModerationPatch(
            current: current,
            actorAdminId: actorAdminId,
            isSuspended: isSuspended,
            suspensionType: suspensionType,
            suspensionUntil: suspensionType == 'temporary'
                ? suspensionUntil
                : null,
          ),
        );
  }
}
