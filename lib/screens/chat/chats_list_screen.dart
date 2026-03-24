import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/chat/message_preview_tile.dart';
import '../../widgets/common/branded_state_view.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isMessageRequest({
    required ChatModel chat,
    required String currentUserId,
    required Set<String> followingIds,
    required Set<String> followerIds,
  }) {
    if (chat.isGroup) return false;
    final otherUserId = chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) return false;
    final followsThem = followingIds.contains(otherUserId);
    final followsMe = followerIds.contains(otherUserId);
    return !followsThem && !followsMe;
  }

  List<ChatModel> _applySearch(List<ChatModel> chats) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return chats;
    return chats.where((chat) {
      return chat.lastMessage.toLowerCase().contains(needle) ||
          (chat.groupName ?? '').toLowerCase().contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final chatsAsync = ref.watch(userChatsProvider(currentUser.uid));
    final followingAsync = ref.watch(followingListProvider(currentUser.uid));
    final followersAsync = ref.watch(followersListProvider(currentUser.uid));
    final suggestedAsync = ref.watch(recommendedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            tooltip: 'Write new message',
            onPressed: () => context.push('/chat/new-select'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Inbox'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search messages',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: chatsAsync.when(
              data: (chats) {
                final followingIds =
                    followingAsync.valueOrNull
                        ?.map((e) => e.followingId)
                        .toSet() ??
                    <String>{};
                final followerIds =
                    followersAsync.valueOrNull
                        ?.map((e) => e.followerId)
                        .toSet() ??
                    <String>{};

                final inbox = _applySearch(
                  chats
                      .where(
                        (chat) => !_isMessageRequest(
                          chat: chat,
                          currentUserId: currentUser.uid,
                          followingIds: followingIds,
                          followerIds: followerIds,
                        ),
                      )
                      .toList(),
                );

                final requests = _applySearch(
                  chats
                      .where(
                        (chat) => _isMessageRequest(
                          chat: chat,
                          currentUserId: currentUser.uid,
                          followingIds: followingIds,
                          followerIds: followerIds,
                        ),
                      )
                      .toList(),
                );

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _ChatsListView(
                      chats: inbox,
                      currentUserId: currentUser.uid,
                    ),
                    Column(
                      children: [
                        if (suggestedAsync.valueOrNull?.isNotEmpty == true)
                          _SuggestedUsersStrip(
                            users: suggestedAsync.valueOrNull!,
                          ),
                        Expanded(
                          child: _ChatsListView(
                            chats: requests,
                            currentUserId: currentUser.uid,
                            emptyTitle: 'No message requests',
                            emptySubtitle:
                                'Requests from non-friends appear here.',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => BrandedStateView(
                icon: Icons.error_outline,
                title: 'Messages unavailable',
                subtitle: '$e',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatsListView extends StatelessWidget {
  final List<ChatModel> chats;
  final String currentUserId;
  final String emptyTitle;
  final String emptySubtitle;

  const _ChatsListView({
    required this.chats,
    required this.currentUserId,
    this.emptyTitle = 'No messages yet',
    this.emptySubtitle = 'Start a conversation.',
  });

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return BrandedStateView(
        icon: Icons.chat_bubble_outline,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        return _ChatTile(chat: chats[index], currentUserId: currentUserId);
      },
    );
  }
}

class _SuggestedUsersStrip extends StatelessWidget {
  final List<UserModel> users;

  const _SuggestedUsersStrip({required this.users});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: users.length > 8 ? 8 : users.length,
        separatorBuilder: (_, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final user = users[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/profile/${user.uid}'),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
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
        error: (_, stackTrace) => MessagePreviewTile(
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
