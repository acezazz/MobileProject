import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/message_search_result.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';

class ChatRepository {
  final ChatService _chatService;

  ChatRepository({ChatService? chatService})
    : _chatService = chatService ?? ChatService();

  /// Start or resume a 1-to-1 chat. Returns the chat ID.
  Future<String> getOrCreateDirectChat(
    String currentUserId,
    String otherUserId,
  ) async {
    // Check for existing chat
    final existing = await _chatService.findDirectChat(
      currentUserId,
      otherUserId,
    );
    if (existing != null) return existing.id;

    // Create new chat
    final chat = ChatModel(
      id: '',
      participants: [currentUserId, otherUserId],
      isGroup: false,
      lastMessageTime: DateTime.now(),
      createdAt: DateTime.now(),
    );
    return _chatService.createChat(chat);
  }

  /// Create a new group chat
  Future<String> createGroupChat({
    required String createdBy,
    required List<String> participants,
    required String groupName,
    String? groupPhoto,
  }) async {
    final chat = ChatModel(
      id: '',
      participants: participants,
      isGroup: true,
      groupName: groupName,
      groupPhoto: groupPhoto,
      createdBy: createdBy,
      lastMessageTime: DateTime.now(),
      createdAt: DateTime.now(),
    );
    return _chatService.createChat(chat);
  }

  Stream<List<ChatModel>> getUserChatsStream(String userId) =>
      _chatService.getUserChatsStream(userId);

  Future<ChatModel?> getChatById(String chatId) =>
      _chatService.getChatById(chatId);

  /// Send a message in a chat
  Future<String> sendMessage({
    required String chatId,
    required UserModel sender,
    required String content,
    String? imageUrl,
  }) {
    final message = MessageModel(
      id: '',
      chatId: chatId,
      senderId: sender.uid,
      senderName: sender.name,
      content: content,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );
    return _chatService.sendMessage(chatId, message);
  }

  Stream<List<MessageModel>> getMessagesStream(
    String chatId,
    String currentUserId,
  ) => _chatService.getMessagesStream(chatId, currentUserId);

  Future<void> markMessagesAsSeen(String chatId, String currentUserId) =>
      _chatService.markMessagesAsSeen(chatId, currentUserId);

  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    MessageStatus status,
  ) => _chatService.updateMessageStatus(chatId, messageId, status);

  Future<void> addParticipant(String chatId, String userId) =>
      _chatService.addParticipant(chatId, userId);

  Future<void> removeParticipant(String chatId, String userId) =>
      _chatService.removeParticipant(chatId, userId);

  Future<void> updateGroupInfo(String chatId, Map<String, dynamic> data) =>
      _chatService.updateChat(chatId, data);

  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String currentUserId,
  }) => _chatService.deleteMessageForEveryone(chatId, messageId, currentUserId);

  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String currentUserId,
  }) => _chatService.deleteMessageForMe(chatId, messageId, currentUserId);

  Future<void> deleteConversationForMe({
    required String chatId,
    required String currentUserId,
  }) => _chatService.deleteConversationForMe(chatId, currentUserId);

  Future<void> deleteConversationForEveryone({
    required String chatId,
    required String currentUserId,
  }) => _chatService.deleteConversationForEveryone(chatId, currentUserId);

  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String currentUserId,
    required String emoji,
  }) => _chatService.setMessageReaction(
    chatId: chatId,
    messageId: messageId,
    currentUserId: currentUserId,
    emoji: emoji,
  );

  Future<void> removeMessageReaction({
    required String chatId,
    required String messageId,
    required String currentUserId,
  }) => _chatService.removeMessageReaction(
    chatId: chatId,
    messageId: messageId,
    currentUserId: currentUserId,
  );

  Future<int> bulkDeleteOwnMessages({
    required String chatId,
    required List<String> messageIds,
    required String currentUserId,
  }) => _chatService.bulkDeleteOwnMessages(chatId, messageIds, currentUserId);

  Future<List<MessageSearchResult>> searchMessagesGlobal({
    required String currentUserId,
    required String query,
    int perChatLimit = 80,
    int limit = 100,
  }) => _chatService.searchMessagesGlobal(
    currentUserId: currentUserId,
    query: query,
    perChatLimit: perChatLimit,
    limit: limit,
  );

  Future<List<MessageSearchResult>> searchMessagesInChat({
    required String chatId,
    required String query,
    required String currentUserId,
    int limit = 100,
  }) => _chatService.searchMessagesInChat(
    chatId: chatId,
    query: query,
    currentUserId: currentUserId,
    limit: limit,
  );
}
