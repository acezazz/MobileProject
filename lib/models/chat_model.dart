import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final String? createdBy;
  final String lastMessage;
  final String lastMessageSenderId;
  final List<String> deletedForUsers;
  final List<String> blockedBy;
  final Map<String, bool> mediaPermissions;
  final DateTime lastMessageTime;
  final DateTime createdAt;

  const ChatModel({
    required this.id,
    required this.participants,
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    this.createdBy,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    this.deletedForUsers = const [],
    this.blockedBy = const [],
    this.mediaPermissions = const {},
    required this.lastMessageTime,
    required this.createdAt,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChatModel(
      id: docId,
      participants: List<String>.from(map['participants'] ?? []),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'],
      groupPhoto: map['groupPhoto'],
      createdBy: map['createdBy'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      deletedForUsers: List<String>.from(map['deletedForUsers'] ?? const []),
      blockedBy: List<String>.from(map['blockedBy'] ?? const []),
      mediaPermissions: Map<String, bool>.from(
        map['mediaPermissions'] ?? const <String, bool>{},
      ),
      lastMessageTime:
          (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupPhoto': groupPhoto,
      'createdBy': createdBy,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'deletedForUsers': deletedForUsers,
      'blockedBy': blockedBy,
      'mediaPermissions': mediaPermissions,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ChatModel copyWith({
    String? lastMessage,
    String? lastMessageSenderId,
    List<String>? deletedForUsers,
    List<String>? blockedBy,
    Map<String, bool>? mediaPermissions,
    DateTime? lastMessageTime,
    String? groupName,
    String? groupPhoto,
    List<String>? participants,
  }) {
    return ChatModel(
      id: id,
      participants: participants ?? this.participants,
      isGroup: isGroup,
      groupName: groupName ?? this.groupName,
      groupPhoto: groupPhoto ?? this.groupPhoto,
      createdBy: createdBy,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      deletedForUsers: deletedForUsers ?? this.deletedForUsers,
      blockedBy: blockedBy ?? this.blockedBy,
      mediaPermissions: mediaPermissions ?? this.mediaPermissions,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      createdAt: createdAt,
    );
  }
}
