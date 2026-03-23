import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _usersRef =>
      _firestore.collection(FirestoreConstants.usersCollection);

  Future<void> createUserProfile(UserModel user) async {
    await _usersRef.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }

    // Backward-compatibility for legacy user docs stored with auto IDs.
    final fallback = await _usersRef
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (fallback.docs.isEmpty) return null;

    final legacyDoc = fallback.docs.first;
    return UserModel.fromMap(
      legacyDoc.data() as Map<String, dynamic>,
      legacyDoc.id,
    );
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _usersRef.doc(uid).snapshots().asyncMap((doc) async {
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }

      final fallback = await _usersRef
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (fallback.docs.isEmpty) return null;

      final legacyDoc = fallback.docs.first;
      return UserModel.fromMap(
        legacyDoc.data() as Map<String, dynamic>,
        legacyDoc.id,
      );
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _usersRef.doc(uid).update(data);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final query = await _usersRef
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<List<UserModel>> searchUsers(String query) async {
    final snapshot = await _usersRef
        .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
        .where('username', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
        .limit(20)
        .get();
    return snapshot.docs
        .map(
          (doc) =>
              UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<List<UserModel>> getTopUsersByFollowers({int limit = 30}) async {
    final snapshot = await _usersRef
        .orderBy('followersCount', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
              UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  Future<int> getFollowersCount(String userId) async {
    final snapshot = await _firestore
        .collection(FirestoreConstants.followersCollection)
        .where('followingId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Stream<int> followersCountStream(String userId) {
    return _firestore
        .collection(FirestoreConstants.followersCollection)
        .where('followingId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<int> getFollowingCount(String userId) async {
    final snapshot = await _firestore
        .collection(FirestoreConstants.followersCollection)
        .where('followerId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Stream<int> followingCountStream(String userId) {
    return _firestore
        .collection(FirestoreConstants.followersCollection)
        .where('followerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<void> deleteUserProfile(String uid) async {
    await _usersRef.doc(uid).delete();
  }
}
