import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../core/constants/firestore_constants.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/message_search_result.dart';

class ChatService {
  final FirebaseFirestore _firestore;
  static const String _deletedPlaceholder = 'This message was deleted';

  ChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _chatsRef =>
      _firestore.collection(FirestoreConstants.chatsCollection);
  CollectionReference get _followersRef =>
      _firestore.collection(FirestoreConstants.followersCollection);

  // --- Chats ---

  Future<String> createChat(ChatModel chat) async {
    final map = chat.toMap();
    if (!chat.isGroup && chat.participants.length == 2) {
      final sorted = List<String>.from(chat.participants)..sort();
      map['participantHash'] = '${sorted[0]}_${sorted[1]}';
    }
    final docRef = await _chatsRef.add(map);
    return docRef.id;
  }

  /// Find an existing 1-to-1 chat between two users using O(1) hash lookup
  Future<ChatModel?> findDirectChat(String userId1, String userId2) async {
    try {
      final sorted = [userId1, userId2]..sort();
      final hash = '${sorted[0]}_${sorted[1]}';

      final snapshot = await _chatsRef
          .where('participantHash', isEqualTo: hash)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ChatModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id,
        );
      }
    } catch (e) {
      // Fallback or log if needed
    }
    return null;
  }

  /// Get all chats for a user (real-time)
  Stream<List<ChatModel>> getUserChatsStream(String userId) {
    return _chatsRef
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .where((chat) => !chat.deletedForUsers.contains(userId))
              .toList(),
        );
  }

  Future<ChatModel?> getChatById(String chatId) async {
    final doc = await _chatsRef.doc(chatId).get();
    if (!doc.exists) return null;
    return ChatModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> updateChat(String chatId, Map<String, dynamic> data) async {
    await _chatsRef.doc(chatId).update(data);
  }

  Future<bool> areUsersConnected(
    String currentUserId,
    String otherUserId,
  ) async {
    final following = await _followersRef
        .where('followerId', isEqualTo: currentUserId)
        .where('followingId', isEqualTo: otherUserId)
        .limit(1)
        .get();
    if (following.docs.isNotEmpty) return true;

    final followedBack = await _followersRef
        .where('followerId', isEqualTo: otherUserId)
        .where('followingId', isEqualTo: currentUserId)
        .limit(1)
        .get();
    return followedBack.docs.isNotEmpty;
  }

  // --- Messages ---

  Future<String> sendMessage(String chatId, MessageModel message) async {
    final chatSnapshot = await _chatsRef.doc(chatId).get();
    if (!chatSnapshot.exists) {
      throw Exception('Chat not found');
    }

    final chatData = chatSnapshot.data() as Map<String, dynamic>;
    final legacyBlockedBy = chatData['blockedBy'];
    final isBlocked =
        (chatData['isBlocked'] as bool?) ??
        (legacyBlockedBy is String && legacyBlockedBy.isNotEmpty) ||
            (legacyBlockedBy is List && legacyBlockedBy.isNotEmpty);
    if (isBlocked) {
      throw Exception('Conversation is blocked');
    }

    final statusRaw = (chatData['status'] as String?) ?? 'accepted';
    final requestedBy = chatData['requestedBy'] as String?;
    final shouldAcceptRequest =
        statusRaw == ChatConversationStatus.request.name &&
        requestedBy != null &&
        requestedBy != message.senderId;

    final batch = _firestore.batch();

    final messageRef = _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .doc();

    batch.set(messageRef, message.toMap());

    // Update chat with last message info
    batch.update(_chatsRef.doc(chatId), {
      'lastMessage': message.content,
      'lastMessageSenderId': message.senderId,
      'lastMessageTime': Timestamp.fromDate(message.createdAt),
      if (shouldAcceptRequest) 'status': ChatConversationStatus.accepted.name,
      if (shouldAcceptRequest) 'requestedBy': null,
    });

    await batch.commit();
    return messageRef.id;
  }

  /// Get messages for a chat (real-time)
  Stream<List<MessageModel>> getMessagesStream(
    String chatId,
    String currentUserId,
  ) {
    return _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final message = MessageModel.fromMap(doc.data(), doc.id);
            if (!message.deletedForUsers.contains(currentUserId)) {
              return message;
            }

            return MessageModel(
              id: message.id,
              chatId: message.chatId,
              senderId: message.senderId,
              senderName: message.senderName,
              content: 'You deleted this message',
              imageUrl: null,
              isDeletedForEveryone: true,
              deletedForUsers: message.deletedForUsers,
              deletedAt: message.deletedAt,
              deletedBy: currentUserId,
              status: message.status,
              createdAt: message.createdAt,
            );
          }).toList(),
        );
  }

  /// Update message status (sent → delivered → seen)
  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    MessageStatus status,
  ) async {
    await _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .doc(messageId)
        .update({'status': status.name});
  }

  /// Mark all messages from other users as seen
  Future<void> markMessagesAsSeen(String chatId, String currentUserId) async {
    // Firestore allows only one inequality filter.
    // Filtering by status prevents fetching the *entire* chat history.
    final snapshot = await _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .where('status', isNotEqualTo: MessageStatus.seen.name)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final senderId = data['senderId'] as String?;

      // Filter out our own messages client-side
      if (senderId != currentUserId) {
        batch.update(doc.reference, {'status': MessageStatus.seen.name});
      }
    }
    await batch.commit();
  }

  /// Add a participant to a group chat
  Future<void> addParticipant(String chatId, String userId) async {
    await _chatsRef.doc(chatId).update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  /// Remove a participant from a group chat
  Future<void> removeParticipant(String chatId, String userId) async {
    await _chatsRef.doc(chatId).update({
      'participants': FieldValue.arrayRemove([userId]),
    });
  }

  /// Delete own message for everyone by replacing payload with a placeholder.
  Future<void> deleteMessageForEveryone(
    String chatId,
    String messageId,
    String currentUserId,
  ) async {
    final messageRef = _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .doc(messageId);
    final messageDoc = await messageRef.get();

    if (!messageDoc.exists) {
      throw Exception('Message not found');
    }

    final data = messageDoc.data() as Map<String, dynamic>;
    final senderId = data['senderId'] as String? ?? '';
    if (senderId != currentUserId) {
      throw Exception('You can only delete your own messages');
    }

    final imageUrl = data['imageUrl'] as String?;

    await messageRef.update({
      'content': _deletedPlaceholder,
      'imageUrl': null,
      'isDeletedForEveryone': true,
      'deletedAt': Timestamp.now(),
      'deletedBy': currentUserId,
    });

    await _attemptRemoteMediaDelete(imageUrl);

    await _refreshChatLastMessage(chatId);
  }

  Future<void> deleteMessageForMe(
    String chatId,
    String messageId,
    String currentUserId,
  ) async {
    final chatDoc = await _chatsRef.doc(chatId).get();
    if (!chatDoc.exists) throw Exception('Chat not found');

    final chatData = chatDoc.data() as Map<String, dynamic>;
    final participants = List<String>.from(
      chatData['participants'] ?? const [],
    );
    if (!participants.contains(currentUserId)) {
      throw Exception('Unauthorized message delete');
    }

    final messageRef = _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .doc(messageId);

    await messageRef.update({
      'deletedForUsers': FieldValue.arrayUnion([currentUserId]),
    });
  }

  Future<void> deleteConversationForMe(
    String chatId,
    String currentUserId,
  ) async {
    final chatRef = _chatsRef.doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) throw Exception('Chat not found');

    final data = chatDoc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? const []);
    if (!participants.contains(currentUserId)) {
      throw Exception('Unauthorized conversation delete');
    }

    await chatRef.update({
      'deletedForUsers': FieldValue.arrayUnion([currentUserId]),
    });
  }

  Future<void> deleteConversationForEveryone(
    String chatId,
    String currentUserId,
  ) async {
    final chatRef = _chatsRef.doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) throw Exception('Chat not found');

    final data = chatDoc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? const []);
    if (!participants.contains(currentUserId)) {
      throw Exception('Unauthorized conversation delete');
    }

    final messagesSnapshot = await chatRef
        .collection(FirestoreConstants.messagesSubcollection)
        .get();

    final batch = _firestore.batch();
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(chatRef);
    await batch.commit();
  }

  Future<void> setMessageReaction({
    required String chatId,
    required String messageId,
    required String currentUserId,
    required String emoji,
  }) async {
    final messageRef = _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .doc(messageId);

    final snapshot = await messageRef.get();
    if (!snapshot.exists) {
      throw Exception('Message not found');
    }

    final message = MessageModel.fromMap(snapshot.data()!, snapshot.id);
    if (!message.canReceiveReactions) {
      throw Exception('Cannot react to deleted message');
    }

    await messageRef.update({'reactions.$currentUserId': emoji});
  }

  Future<void> removeMessageReaction({
    required String chatId,
    required String messageId,
    required String currentUserId,
  }) async {
    final messageRef = _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .doc(messageId);

    await messageRef.update({'reactions.$currentUserId': FieldValue.delete()});
  }

  /// Bulk delete own messages for everyone.
  Future<int> bulkDeleteOwnMessages(
    String chatId,
    List<String> messageIds,
    String currentUserId,
  ) async {
    if (messageIds.isEmpty) return 0;

    final messagesCollection = _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection);
    var deletedCount = 0;

    for (final messageId in messageIds) {
      final messageRef = messagesCollection.doc(messageId);
      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) continue;

      final data = messageDoc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String? ?? '';
      if (senderId != currentUserId) continue;

      final imageUrl = data['imageUrl'] as String?;

      await messageRef.update({
        'content': _deletedPlaceholder,
        'imageUrl': null,
        'isDeletedForEveryone': true,
        'deletedAt': Timestamp.now(),
        'deletedBy': currentUserId,
      });
      await _attemptRemoteMediaDelete(imageUrl);
      deletedCount++;
    }

    if (deletedCount > 0) {
      await _refreshChatLastMessage(chatId);
    }

    return deletedCount;
  }

  Future<void> _attemptRemoteMediaDelete(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;

    try {
      final uri = Uri.parse(imageUrl);
      if (uri.host.contains('res.cloudinary.com')) {
        // Best-effort cleanup call; ignore failures to keep delete action reliable.
        await http.get(uri).timeout(const Duration(milliseconds: 1500));
      }
    } catch (_) {
      // Intentionally ignored.
    }
  }

  Future<void> _refreshChatLastMessage(String chatId) async {
    final latestSnapshot = await _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (latestSnapshot.docs.isEmpty) {
      await _chatsRef.doc(chatId).update({
        'lastMessage': '',
        'lastMessageSenderId': '',
        'lastMessageTime': Timestamp.now(),
      });
      return;
    }

    final latestData = latestSnapshot.docs.first.data();
    await _chatsRef.doc(chatId).update({
      'lastMessage': latestData['content'] ?? '',
      'lastMessageSenderId': latestData['senderId'] ?? '',
      'lastMessageTime': latestData['createdAt'] ?? Timestamp.now(),
    });
  }

  Future<List<MessageSearchResult>> searchMessagesGlobal({
    required String currentUserId,
    required String query,
    int perChatLimit = 80,
    int limit = 100,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final chatsSnapshot = await _chatsRef
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .limit(40)
        .get();

    final results = <MessageSearchResult>[];

    for (final chatDoc in chatsSnapshot.docs) {
      final chatId = chatDoc.id;
      final chatData = chatDoc.data() as Map<String, dynamic>;
      final isGroup = (chatData['isGroup'] as bool?) ?? false;
      final participants = List<String>.from(chatData['participants'] ?? []);
      final chatName = await _resolveChatName(
        chatData: chatData,
        currentUserId: currentUserId,
        participants: participants,
      );

      final messageSnapshot = await _chatsRef
          .doc(chatId)
          .collection(FirestoreConstants.messagesSubcollection)
          .orderBy('createdAt', descending: true)
          .limit(perChatLimit)
          .get();

      for (final messageDoc in messageSnapshot.docs) {
        final message = MessageModel.fromMap(messageDoc.data(), messageDoc.id);
        final content = message.content.trim();
        if (content.isEmpty) continue;
        if (!content.toLowerCase().contains(normalized)) continue;

        results.add(
          MessageSearchResult(
            chatId: chatId,
            messageId: message.id,
            chatName: chatName,
            isGroup: isGroup,
            senderId: message.senderId,
            senderName: message.senderName,
            snippet: content,
            createdAt: message.createdAt,
          ),
        );
      }
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (results.length <= limit) return results;
    return results.take(limit).toList();
  }

  Future<List<MessageSearchResult>> searchMessagesInChat({
    required String chatId,
    required String query,
    required String currentUserId,
    int limit = 100,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final chatDoc = await _chatsRef.doc(chatId).get();
    if (!chatDoc.exists) return [];
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final isGroup = (chatData['isGroup'] as bool?) ?? false;
    final participants = List<String>.from(chatData['participants'] ?? []);
    final chatName = await _resolveChatName(
      chatData: chatData,
      currentUserId: currentUserId,
      participants: participants,
    );

    final messagesSnapshot = await _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesSubcollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final results = <MessageSearchResult>[];
    for (final messageDoc in messagesSnapshot.docs) {
      final message = MessageModel.fromMap(messageDoc.data(), messageDoc.id);
      final content = message.content.trim();
      if (content.isEmpty) continue;
      if (!content.toLowerCase().contains(normalized)) continue;

      results.add(
        MessageSearchResult(
          chatId: chatId,
          messageId: message.id,
          chatName: chatName,
          isGroup: isGroup,
          senderId: message.senderId,
          senderName: message.senderName,
          snippet: content,
          createdAt: message.createdAt,
        ),
      );
    }

    return results;
  }

  Future<String> _resolveChatName({
    required Map<String, dynamic> chatData,
    required String currentUserId,
    required List<String> participants,
  }) async {
    final isGroup = (chatData['isGroup'] as bool?) ?? false;
    if (isGroup) {
      return (chatData['groupName'] as String?)?.trim().isNotEmpty == true
          ? (chatData['groupName'] as String)
          : 'Group chat';
    }

    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) return 'Direct chat';

    final userDoc = await _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(otherUserId)
        .get();
    if (!userDoc.exists) return 'Direct chat';
    final userData = userDoc.data() as Map<String, dynamic>;
    final name = (userData['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return 'Direct chat';
    return name;
  }
}
