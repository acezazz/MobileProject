import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sent, delivered, seen }

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String content;
  final String? imageUrl;
  final Map<String, String> reactions;
  final bool isDeletedForEveryone;
  final List<String> deletedForUsers;
  final DateTime? deletedAt;
  final String? deletedBy;
  final MessageStatus status;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.imageUrl,
    this.reactions = const {},
    this.isDeletedForEveryone = false,
    this.deletedForUsers = const [],
    this.deletedAt,
    this.deletedBy,
    this.status = MessageStatus.sent,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return MessageModel(
      id: docId,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      reactions: Map<String, String>.from(map['reactions'] ?? const {}),
      isDeletedForEveryone: map['isDeletedForEveryone'] ?? false,
      deletedForUsers: List<String>.from(map['deletedForUsers'] ?? const []),
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      deletedBy: map['deletedBy'],
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.sent,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'imageUrl': imageUrl,
      'reactions': reactions,
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedForUsers': deletedForUsers,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deletedBy': deletedBy,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  bool get isDeleted => isDeletedForEveryone;

  bool get canReceiveReactions => !isDeletedForEveryone;
}
