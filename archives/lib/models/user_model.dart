import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String username;
  final String email;
  final String bio;
  final String profilePhoto;
  final bool isPrivate;
  final String status; // 'active', 'deactivated', 'suspended'
  final DateTime createdAt;
  final int followersCount;
  final int followingCount;

  const UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    this.bio = '',
    this.profilePhoto = '',
    this.isPrivate = false,
    this.status = 'active',
    required this.createdAt,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    String asString(dynamic value) => value == null ? '' : '$value';
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}') ?? 0;
    }

    bool asBool(dynamic value) {
      if (value is bool) return value;
      final raw = asString(value).trim().toLowerCase();
      return raw == 'true' || raw == '1' || raw == 'yes';
    }

    DateTime asDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        final milliseconds = value > 9999999999 ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
      final parsed = DateTime.tryParse(asString(value));
      return parsed ?? DateTime.now();
    }

    final uidFromData = asString(map['uid']).trim();

    return UserModel(
      uid: uidFromData.isNotEmpty ? uidFromData : docId,
      name: asString(map['name']),
      username: asString(map['username']),
      email: asString(map['email']),
      bio: asString(map['bio']),
      profilePhoto: asString(map['profilePhoto']),
      isPrivate: asBool(map['isPrivate']),
      status: asString(map['status']).isEmpty
          ? 'active'
          : asString(map['status']),
      createdAt: asDateTime(map['createdAt']),
      followersCount: asInt(map['followersCount']),
      followingCount: asInt(map['followingCount']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'email': email,
      'bio': bio,
      'profilePhoto': profilePhoto,
      'isPrivate': isPrivate,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }

  UserModel copyWith({
    String? name,
    String? username,
    String? email,
    String? bio,
    String? profilePhoto,
    bool? isPrivate,
    String? status,
    int? followersCount,
    int? followingCount,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      isPrivate: isPrivate ?? this.isPrivate,
      status: status ?? this.status,
      createdAt: createdAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}
