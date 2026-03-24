import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/branded_state_view.dart';
import '../../widgets/common/custom_text_field.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isCreatingChat = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startChat(String otherUserId) async {
    if (_isCreatingChat) return;

    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    setState(() => _isCreatingChat = true);
    try {
      final chatId = await ref
          .read(chatRepositoryProvider)
          .getOrCreateDirectChat(currentUser.uid, otherUserId);

      if (mounted) {
        context.push('/chat/$chatId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingChat = false);
      }
    }
  }

  List<UserModel> _excludeUsersWithExistingDirectChat({
    required List<UserModel> users,
    required List<ChatModel> chats,
    required String currentUserId,
  }) {
    final existingDirectPartnerIds = chats
        .where((chat) => !chat.isGroup)
        .map((chat) {
          return chat.participants.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
        })
        .where((id) => id.isNotEmpty)
        .toSet();

    return users
        .where((user) => !existingDirectPartnerIds.contains(user.uid))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: BrandedStateView(
            icon: Icons.error_outline,
            title: 'User not found',
            subtitle: 'Please login again.',
          ),
        ),
      );
    }

    final resultsAsync = ref.watch(searchUsersProvider(_query));
    final recommendedAsync = ref.watch(recommendedUsersProvider);
    final chatsAsync = ref.watch(userChatsProvider(currentUser.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('New Message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: CustomTextField(
              controller: _searchController,
              hintText: 'Search users...',
              fillColor: AppColors.accentBeige,
              textColor: AppColors.inkDark,
              hintColor: AppColors.inkDark,
              prefixIcon: const Icon(Icons.search, color: AppColors.inkDark),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
          Expanded(
            child: chatsAsync.when(
              data: (chats) {
                if (_query.trim().isEmpty) {
                  return recommendedAsync.when(
                    data: (recommendedUsers) {
                      final filteredUsers = _excludeUsersWithExistingDirectChat(
                        users: recommendedUsers,
                        chats: chats,
                        currentUserId: currentUser.uid,
                      );

                      if (filteredUsers.isEmpty) {
                        return const BrandedStateView(
                          icon: Icons.chat_bubble_outline,
                          title: 'No recommended users',
                          subtitle:
                              'Search for a user to start a conversation.',
                        );
                      }

                      return _buildUserList(filteredUsers);
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => BrandedStateView(
                      icon: Icons.error_outline,
                      title: 'Could not load recommended users',
                      subtitle: '$e',
                    ),
                  );
                }

                return resultsAsync.when(
                  data: (users) {
                    final filteredUsers = _excludeUsersWithExistingDirectChat(
                      users: users,
                      chats: chats,
                      currentUserId: currentUser.uid,
                    );

                    if (filteredUsers.isEmpty) {
                      return const BrandedStateView(
                        icon: Icons.search_off,
                        title: 'No users found',
                        subtitle: 'Try a different name or username.',
                      );
                    }

                    return _buildUserList(filteredUsers);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => BrandedStateView(
                    icon: Icons.error_outline,
                    title: 'Could not load users',
                    subtitle: '$e',
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => BrandedStateView(
                icon: Icons.error_outline,
                title: 'Could not load chats',
                subtitle: '$e',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<UserModel> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: AvatarWidget(
              imageUrl: user.profilePhoto,
              name: user.name,
              radius: 24,
            ),
            title: Text(
              user.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '@${user.username}',
              style: const TextStyle(color: AppColors.textHint),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
            onTap: () => _startChat(user.uid),
          ),
        );
      },
    );
  }
}
