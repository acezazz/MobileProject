class MessageSearchResult {
  final String chatId;
  final String messageId;
  final String chatName;
  final bool isGroup;
  final String senderId;
  final String senderName;
  final String snippet;
  final DateTime createdAt;

  const MessageSearchResult({
    required this.chatId,
    required this.messageId,
    required this.chatName,
    required this.isGroup,
    required this.senderId,
    required this.senderName,
    required this.snippet,
    required this.createdAt,
  });
}
