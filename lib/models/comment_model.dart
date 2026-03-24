import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userUsername;
  final String userProfilePhoto;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.userProfilePhoto = '',
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String docId) {
    return CommentModel(
      id: docId,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userUsername: map['userUsername'] ?? '',
      userProfilePhoto: map['userProfilePhoto'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userUsername': userUsername,
      'userProfilePhoto': userProfilePhoto,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
