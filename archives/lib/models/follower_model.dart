import 'package:cloud_firestore/cloud_firestore.dart';

class FollowerModel {
  final String id;
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  const FollowerModel({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  factory FollowerModel.fromMap(Map<String, dynamic> map, String docId) {
    return FollowerModel(
      id: docId,
      followerId: map['followerId'] ?? '',
      followingId: map['followingId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'followerId': followerId,
      'followingId': followingId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
