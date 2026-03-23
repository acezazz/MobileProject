import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/chat/message_preview_tile.dart';
import '../../widgets/common/branded_state_view.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final chatsAsync = ref.watch(userChatsProvider(currentUser.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            onPressed: () => context.push('/chat/new-select'),
          ),
        ],
      ),
      body: chatsAsync.when(
        data: (chats) {
          if (chats.isEmpty) {
            return const BrandedStateView(
              icon: Icons.chat_bubble_outline,
              title: 'No messages yet',
              subtitle: 'Start a conversation.',
            );
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              return _ChatTile(
                chat: chats[index],
                currentUserId: currentUser.uid,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BrandedStateView(
          icon: Icons.error_outline,
          title: 'Messages unavailable',
          subtitle: '$e',
        ),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  final ChatModel chat;
  final String currentUserId;

  const _ChatTile({required this.chat, required this.currentUserId});

  String _fallbackOtherUserId() {
    return chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
  }

  String _fallbackLabelFromUserId(String userId) {
    final suffix = userId.length >= 6 ? userId.substring(0, 6) : userId;
    return 'User $suffix';
  }

  String _resolveDisplayName({
    required String otherUserId,
    String? name,
    String? username,
  }) {
    final cleanName = (name ?? '').trim();
    if (cleanName.isNotEmpty) return cleanName;

    final cleanUsername = (username ?? '').trim();
    if (cleanUsername.isNotEmpty) return '@$cleanUsername';

    return _fallbackLabelFromUserId(otherUserId);
  }

  Future<void> _showChatDeleteActions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Delete for me'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref
                    .read(chatRepositoryProvider)
                    .deleteConversationForMe(
                      chatId: chat.id,
                      currentUserId: currentUserId,
                    );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.redAccent,
              ),
              title: const Text('Delete for everyone'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref
                    .read(chatRepositoryProvider)
                    .deleteConversationForEveryone(
                      chatId: chat.id,
                      currentUserId: currentUserId,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For 1-to-1 chats, show the other user's info
    if (!chat.isGroup) {
      final otherUserId = _fallbackOtherUserId();
      final otherUserAsync = ref.watch(userProfileProvider(otherUserId));

      return otherUserAsync.when(
        data: (user) {
          return MessagePreviewTile(
            name: _resolveDisplayName(
              otherUserId: otherUserId,
              name: user?.name,
              username: user?.username,
            ),
            imageUrl: user?.profilePhoto,
            preview: chat.lastMessage.isNotEmpty
                ? chat.lastMessage
                : 'No messages yet',
            timestamp: timeago.format(chat.lastMessageTime, locale: 'en_short'),
            onTap: () => context.push('/chat/${chat.id}'),
            onLongPress: () => _showChatDeleteActions(context, ref),
          );
        },
        loading: () =>
            const ListTile(leading: CircleAvatar(), title: Text('Loading...')),
        error: (_, _) => MessagePreviewTile(
          name: _fallbackLabelFromUserId(otherUserId),
          preview: chat.lastMessage.isNotEmpty
              ? chat.lastMessage
              : 'No messages yet',
          timestamp: timeago.format(chat.lastMessageTime, locale: 'en_short'),
          onTap: () => context.push('/chat/${chat.id}'),
          onLongPress: () => _showChatDeleteActions(context, ref),
        ),
      );
    }

    // Group chat
    return MessagePreviewTile(
      name: chat.groupName ?? 'Group Chat',
      preview: chat.lastMessage.isNotEmpty
          ? chat.lastMessage
          : 'No messages yet',
      timestamp: timeago.format(chat.lastMessageTime, locale: 'en_short'),
      isGroup: true,
      onTap: () => context.push('/chat/${chat.id}'),
      onLongPress: () => _showChatDeleteActions(context, ref),
    );
  }
}
