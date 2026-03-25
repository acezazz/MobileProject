import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String username;
  final String email;
  final DateTime? birthDate;
  final String gender;
  final String bio;
  final String profilePhoto;
  final bool isPrivate;
  final String status; // 'active', 'deactivated', 'suspended'
  final String role; // 'user', 'admin'
  final bool isSuspended;
  final String suspensionType; // 'none', 'temporary', 'permanent'
  final DateTime? suspensionUntil;
  final int warningsCount;
  final int strikesCount;
  final DateTime? suspendedAt;
  final String? suspensionReason;
  final String? updatedByAdminId;
  final DateTime? updatedAt;
  final DateTime createdAt;
  final int followersCount;
  final int followingCount;

  const UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    this.birthDate,
    this.gender = '',
    this.bio = '',
    this.profilePhoto = '',
    this.isPrivate = false,
    this.status = 'active',
    this.role = 'user',
    this.isSuspended = false,
    this.suspensionType = 'none',
    this.suspensionUntil,
    this.warningsCount = 0,
    this.strikesCount = 0,
    this.suspendedAt,
    this.suspensionReason,
    this.updatedByAdminId,
    this.updatedAt,
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

    String normalizeSuspensionType(String? rawType, bool suspended) {
      if (rawType == 'temporary' ||
          rawType == 'permanent' ||
          rawType == 'none') {
        return rawType!;
      }
      return suspended ? 'permanent' : 'none';
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
    final bool isSuspended = map.containsKey('isSuspended')
        ? asBool(map['isSuspended'])
        : asString(map['status']).toLowerCase() == 'suspended';
    final String suspensionType = normalizeSuspensionType(
      asString(map['suspensionType']).isEmpty
          ? null
          : asString(map['suspensionType']),
      isSuspended,
    );
    final dynamic suspensionUntilRaw =
        map['suspensionUntil'] ?? map['suspensionEnd'];
    final DateTime? suspensionUntil = suspensionUntilRaw == null
        ? null
        : asDateTime(suspensionUntilRaw);
    final int warningsCount = map['warningsCount'] == null
        ? asInt(map['warningCount'])
        : asInt(map['warningsCount']);
    final int strikesCount = asInt(map['strikesCount']);

    final String statusFromMap = asString(map['status']).isEmpty
        ? (isSuspended ? 'suspended' : 'active')
        : asString(map['status']);

    return UserModel(
      uid: uidFromData.isNotEmpty ? uidFromData : docId,
      name: asString(map['name']),
      username: asString(map['username']),
      email: asString(map['email']),
      birthDate: map['birthDate'] == null ? null : asDateTime(map['birthDate']),
      gender: asString(map['gender']),
      bio: asString(map['bio']),
      profilePhoto: asString(map['profilePhoto']),
      role: asString(map['role']).isEmpty ? 'user' : asString(map['role']),
      isPrivate: asBool(map['isPrivate']),
      status: statusFromMap,
      isSuspended: isSuspended,
      suspensionType: suspensionType,
      suspensionUntil: suspensionUntil,
      warningsCount: warningsCount,
      strikesCount: strikesCount,
      suspendedAt: map['suspendedAt'] == null
          ? null
          : asDateTime(map['suspendedAt']),
      suspensionReason: asString(map['suspensionReason']).isEmpty
          ? null
          : asString(map['suspensionReason']),
      updatedByAdminId: asString(map['updatedByAdminId']).isEmpty
          ? null
          : asString(map['updatedByAdminId']),
      updatedAt: map['updatedAt'] == null ? null : asDateTime(map['updatedAt']),
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
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'gender': gender,
      'bio': bio,
      'profilePhoto': profilePhoto,
      'isPrivate': isPrivate,
      'status': status,
      'role': role,
      'isSuspended': isSuspended,
      'suspensionType': suspensionType,
      'suspensionUntil': suspensionUntil == null
          ? null
          : Timestamp.fromDate(suspensionUntil!),
      'suspensionEnd': suspensionUntil == null
          ? null
          : Timestamp.fromDate(suspensionUntil!),
      'warningCount': warningsCount,
      'warningsCount': warningsCount,
      'strikesCount': strikesCount,
      'suspendedAt': suspendedAt == null
          ? null
          : Timestamp.fromDate(suspendedAt!),
      'suspensionReason': suspensionReason,
      'updatedByAdminId': updatedByAdminId,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'followersCount': followersCount,
      'followingCount': followingCount,
    };
  }

  UserModel copyWith({
    String? name,
    String? username,
    String? email,
    DateTime? birthDate,
    String? gender,
    String? bio,
    String? profilePhoto,
    bool? isPrivate,
    String? status,
    bool? isSuspended,
    String? suspensionType,
    DateTime? suspensionUntil,
    int? warningsCount,
    int? strikesCount,
    int? followersCount,
    int? followingCount,
    String? role,
    DateTime? suspendedAt,
    String? suspensionReason,
    String? updatedByAdminId,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      role: role ?? this.role,
      isPrivate: isPrivate ?? this.isPrivate,
      status: status ?? this.status,
      isSuspended: isSuspended ?? this.isSuspended,
      suspensionType: suspensionType ?? this.suspensionType,
      suspensionUntil: suspensionUntil ?? this.suspensionUntil,
      warningsCount: warningsCount ?? this.warningsCount,
      strikesCount: strikesCount ?? this.strikesCount,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspensionReason: suspensionReason ?? this.suspensionReason,
      updatedByAdminId: updatedByAdminId ?? this.updatedByAdminId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}
