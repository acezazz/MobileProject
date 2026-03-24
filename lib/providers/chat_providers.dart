import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/message_search_result.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_service.dart';
import 'auth_providers.dart';

// Service & Repository
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(chatService: ref.read(chatServiceProvider));
});

// User's chats stream (real-time)
final userChatsProvider = StreamProvider.family<List<ChatModel>, String>((
  ref,
  userId,
) {
  return ref.read(chatRepositoryProvider).getUserChatsStream(userId);
});

// Messages stream for a specific chat (real-time)
final chatMessagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  chatId,
) {
  final currentUser = ref.watch(authStateProvider).valueOrNull;
  if (currentUser == null) {
    return const Stream<List<MessageModel>>.empty();
  }

  return ref
      .read(chatRepositoryProvider)
      .getMessagesStream(chatId, currentUser.uid);
});

// Single chat info
final chatInfoProvider = FutureProvider.family<ChatModel?, String>((
  ref,
  chatId,
) {
  return ref.read(chatRepositoryProvider).getChatById(chatId);
});

final globalMessageSearchProvider =
    FutureProvider.family<List<MessageSearchResult>, String>((
      ref,
      query,
    ) async {
      final currentUser = ref.watch(authStateProvider).valueOrNull;
      if (currentUser == null) return [];
      if (query.trim().isEmpty) return [];

      return ref
          .read(chatRepositoryProvider)
          .searchMessagesGlobal(currentUserId: currentUser.uid, query: query);
    });

final inChatMessageSearchProvider =
    FutureProvider.family<
      List<MessageSearchResult>,
      ({String chatId, String query})
    >((ref, args) async {
      final currentUser = ref.watch(authStateProvider).valueOrNull;
      if (currentUser == null) return [];
      if (args.query.trim().isEmpty) return [];

      return ref
          .read(chatRepositoryProvider)
          .searchMessagesInChat(
            chatId: args.chatId,
            query: args.query,
            currentUserId: currentUser.uid,
          );
    });

final setMessageReactionProvider =
    Provider<
      Future<void> Function({
        required String chatId,
        required String messageId,
        required String currentUserId,
        required String emoji,
      })
    >((ref) {
      return ({
        required String chatId,
        required String messageId,
        required String currentUserId,
        required String emoji,
      }) {
        return ref
            .read(chatRepositoryProvider)
            .setMessageReaction(
              chatId: chatId,
              messageId: messageId,
              currentUserId: currentUserId,
              emoji: emoji,
            );
      };
    });

final removeMessageReactionProvider =
    Provider<
      Future<void> Function({
        required String chatId,
        required String messageId,
        required String currentUserId,
      })
    >((ref) {
      return ({
        required String chatId,
        required String messageId,
        required String currentUserId,
      }) {
        return ref
            .read(chatRepositoryProvider)
            .removeMessageReaction(
              chatId: chatId,
              messageId: messageId,
              currentUserId: currentUserId,
            );
      };
    });
