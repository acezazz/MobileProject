import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatConversationStatus { request, accepted }

class ChatModel {
  final String id;
  final List<String> participants;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final String? createdBy;
  final String lastMessage;
  final String lastMessageSenderId;
  final ChatConversationStatus status;
  final String? requestedBy;
  final bool isBlocked;
  final String? blockedBy;
  final List<String> deletedForUsers;
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
    this.status = ChatConversationStatus.accepted,
    this.requestedBy,
    this.isBlocked = false,
    this.blockedBy,
    this.deletedForUsers = const [],
    this.mediaPermissions = const {},
    required this.lastMessageTime,
    required this.createdAt,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawStatus = (map['status'] as String?) ?? 'accepted';
    final status = ChatConversationStatus.values.firstWhere(
      (value) => value.name == rawStatus,
      orElse: () => ChatConversationStatus.accepted,
    );

    final rawBlockedBy = map['blockedBy'];
    final normalizedBlockedBy = rawBlockedBy is String
        ? rawBlockedBy
        : (rawBlockedBy is List && rawBlockedBy.isNotEmpty
              ? rawBlockedBy.first as String?
              : null);

    final normalizedIsBlocked =
        (map['isBlocked'] as bool?) ?? (normalizedBlockedBy != null);

    return ChatModel(
      id: docId,
      participants: List<String>.from(map['participants'] ?? []),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'],
      groupPhoto: map['groupPhoto'],
      createdBy: map['createdBy'],
      lastMessage: map['lastMessage'] ?? '',
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      status: status,
      requestedBy: map['requestedBy'] as String?,
      isBlocked: normalizedIsBlocked,
      blockedBy: normalizedBlockedBy,
      deletedForUsers: List<String>.from(map['deletedForUsers'] ?? const []),
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
      'status': status.name,
      'requestedBy': requestedBy,
      'isBlocked': isBlocked,
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
    ChatConversationStatus? status,
    String? requestedBy,
    bool? isBlocked,
    String? blockedBy,
    List<String>? deletedForUsers,
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
      status: status ?? this.status,
      requestedBy: requestedBy ?? this.requestedBy,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedBy: blockedBy ?? this.blockedBy,
      deletedForUsers: deletedForUsers ?? this.deletedForUsers,
      mediaPermissions: mediaPermissions ?? this.mediaPermissions,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      createdAt: createdAt,
    );
  }
}
