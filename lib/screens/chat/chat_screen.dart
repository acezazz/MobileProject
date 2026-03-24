import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/web_image_picker.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_providers.dart';
import '../../providers/user_providers.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/chat/emoji_reaction_picker.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String? highlightedMessageId;
  final String? currentUserIdOverride;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.highlightedMessageId,
    this.currentUserIdOverride,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Uint8List? _selectedImageBytes;
  bool _isUploading = false;
  final Set<String> _selectedMessageIds = <String>{};
  String? _pendingJumpMessageId;
  String? _activeHighlightMessageId;
  bool _initialJumpHandled = false;
  bool _isSyncingSeen = false;
  String? _lastSeenSyncMessageId;

  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;

  String? _currentUserId() {
    return widget.currentUserIdOverride ??
        ref.read(authStateProvider).valueOrNull?.uid;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final currentUserId = _currentUserId();
    final chat = await ref.read(chatInfoProvider(widget.chatId).future);
    if (chat != null && currentUserId != null) {
      final blocked = chat.blockedBy.contains(currentUserId);
      final mediaEnabled = chat.mediaPermissions[currentUserId] ?? true;
      if (blocked) {
        if (mounted) {
          AppSnackBar.error(context, 'Conversation is blocked.');
        }
        return;
      }
      if (!mediaEnabled) {
        if (mounted) {
          AppSnackBar.error(context, 'Media sending is disabled in settings.');
        }
        return;
      }
    }

    try {
      final (bytes, _) = await pickImageFromBrowser();
      if (!mounted) return;
      if (bytes != null) {
        setState(() => _selectedImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not pick image: $e');
      }
    }
  }

  Future<void> _openInChatSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        var localQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final resultsAsync = ref.watch(
              inChatMessageSearchProvider((
                chatId: widget.chatId,
                query: localQuery,
              )),
            );

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: SizedBox(
                  height: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search in chat',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Type message text...',
                          hintStyle: const TextStyle(color: AppColors.textHint),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textHint,
                          ),
                          suffixIcon: localQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: AppColors.textHint,
                                  ),
                                  onPressed: () => setSheetState(() {
                                    localQuery = '';
                                  }),
                                )
                              : null,
                        ),
                        onChanged: (value) => setSheetState(() {
                          localQuery = value;
                        }),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: localQuery.trim().isEmpty
                            ? const Center(
                                child: Text(
                                  'Start typing to search this chat',
                                  style: TextStyle(color: AppColors.textHint),
                                ),
                              )
                            : resultsAsync.when(
                                data: (results) {
                                  if (results.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'No matching messages',
                                        style: TextStyle(
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: results.length,
                                    itemBuilder: (context, index) {
                                      final item = results[index];
                                      return ListTile(
                                        title: Text(
                                          item.senderName,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          item.snippet,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                        trailing: Text(
                                          timeago.format(
                                            item.createdAt,
                                            locale: 'en_short',
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.textHint,
                                            fontSize: 12,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _pendingJumpMessageId =
                                                item.messageId;
                                          });
                                          Navigator.pop(sheetContext);
                                        },
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, _) => Center(
                                  child: Text(
                                    'Search failed: $e',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _jumpToMessage(
    String messageId,
    List<MessageModel> messages,
    BuildContext context,
  ) {
    final targetIndex = messages.indexWhere((item) => item.id == messageId);
    if (targetIndex < 0) {
      AppSnackBar.info(context, 'Could not highlight that message.');
      return;
    }

    final estimatedOffset = targetIndex * 86.0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        estimatedOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    setState(() {
      _activeHighlightMessageId = messageId;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_activeHighlightMessageId == messageId) {
        setState(() {
          _activeHighlightMessageId = null;
        });
      }
    });
  }

  void _syncSeenStatusIfNeeded(
    List<MessageModel> messages,
    String? currentUserId,
  ) {
    if (currentUserId == null || messages.isEmpty || _isSyncingSeen) return;

    MessageModel? latestUnseenFromOthers;
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.senderId != currentUserId &&
          message.status != MessageStatus.seen) {
        latestUnseenFromOthers = message;
        break;
      }
    }

    if (latestUnseenFromOthers == null) {
      _lastSeenSyncMessageId = null;
      return;
    }

    if (_lastSeenSyncMessageId == latestUnseenFromOthers.id) return;

    _lastSeenSyncMessageId = latestUnseenFromOthers.id;
    _isSyncingSeen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isSyncingSeen = false;
        return;
      }

      try {
        await ref
            .read(chatRepositoryProvider)
            .markMessagesAsSeen(widget.chatId, currentUserId);
      } catch (_) {
        _lastSeenSyncMessageId = null;
      } finally {
        _isSyncingSeen = false;
      }
    });
  }

  void _removeImage() {
    setState(() => _selectedImageBytes = null);
  }

  void _toggleMessageSelection(MessageModel message, bool isMe) {
    if (!isMe) {
      AppSnackBar.info(context, 'You can only select your own messages.');
      return;
    }

    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  Future<void> _deleteMessageForEveryone(MessageModel message) async {
    final currentUserId = _currentUserId();
    if (currentUserId == null) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteMessageForEveryone(
            chatId: widget.chatId,
            messageId: message.id,
            currentUserId: currentUserId,
          );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Delete failed: $e');
      }
    }
  }

  Future<void> _deleteMessageForMe(MessageModel message) async {
    final currentUserId = _currentUserId();
    if (currentUserId == null) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteMessageForMe(
            chatId: widget.chatId,
            messageId: message.id,
            currentUserId: currentUserId,
          );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Delete failed: $e');
      }
    }
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    final currentUserId = _currentUserId();
    if (currentUserId == null) return;

    final selectedIds = _selectedMessageIds.toList();
    try {
      final deletedCount = await ref
          .read(chatRepositoryProvider)
          .bulkDeleteOwnMessages(
            chatId: widget.chatId,
            messageIds: selectedIds,
            currentUserId: currentUserId,
          );

      if (mounted) {
        setState(() => _selectedMessageIds.clear());
        AppSnackBar.success(context, 'Deleted $deletedCount message(s).');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Bulk delete failed: $e');
      }
    }
  }

  void _showMessageActions(MessageModel message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.canReceiveReactions)
              ListTile(
                leading: const Icon(
                  Icons.add_reaction_outlined,
                  color: AppColors.textSecondary,
                ),
                title: const Text(
                  'React',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _showReactionPicker(message);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.textSecondary,
              ),
              title: const Text(
                'Delete for me',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _deleteMessageForMe(message);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Delete for everyone',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _deleteMessageForEveryone(message);
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(
                  Icons.select_all,
                  color: AppColors.textSecondary,
                ),
                title: const Text(
                  'Select for bulk delete',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _toggleMessageSelection(message, true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReactionPicker(MessageModel message) async {
    final currentUserId = _currentUserId();
    if (currentUserId == null || !message.canReceiveReactions) return;
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 420,
          child: EmojiReactionPicker(
            onSelected: (emoji) async {
              Navigator.pop(sheetContext);
              await ref
                  .read(chatRepositoryProvider)
                  .setMessageReaction(
                    chatId: widget.chatId,
                    messageId: message.id,
                    currentUserId: currentUserId,
                    emoji: emoji,
                  );
            },
          ),
        ),
      ),
    );
  }

  void _insertEmojiToComposer(String emoji) {
    final value = _messageController.value;
    final text = value.text;
    final selection = value.selection;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  Future<void> _openComposerEmojiPicker() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 420,
          child: EmojiReactionPicker(
            onSelected: (emoji) {
              _insertEmojiToComposer(emoji);
              Navigator.pop(sheetContext);
            },
          ),
        ),
      ),
    );
  }

  Widget? _buildReactionChips(MessageModel message) {
    if (message.reactions.isEmpty) return null;

    final currentUserId = _currentUserId();
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: sorted.map((entry) {
        final emoji = entry.key;
        final count = entry.value;
        final hasOwnReaction =
            currentUserId != null && message.reactions[currentUserId] == emoji;

        return ActionChip(
          label: Text('$emoji $count'),
          onPressed: () async {
            if (currentUserId == null || !message.canReceiveReactions) return;
            if (hasOwnReaction) {
              await ref
                  .read(chatRepositoryProvider)
                  .removeMessageReaction(
                    chatId: widget.chatId,
                    messageId: message.id,
                    currentUserId: currentUserId,
                  );
            } else {
              await ref
                  .read(chatRepositoryProvider)
                  .setMessageReaction(
                    chatId: widget.chatId,
                    messageId: message.id,
                    currentUserId: currentUserId,
                    emoji: emoji,
                  );
            }
          },
        );
      }).toList(),
    );
  }

  Future<void> _deleteConversationForMe() async {
    final currentUserId = ref.read(authStateProvider).valueOrNull?.uid;
    if (currentUserId == null) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteConversationForMe(
            chatId: widget.chatId,
            currentUserId: currentUserId,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Delete failed: $e');
      }
    }
  }

  Future<void> _deleteConversationForEveryone() async {
    final currentUserId = ref.read(authStateProvider).valueOrNull?.uid;
    if (currentUserId == null) return;

    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteConversationForEveryone(
            chatId: widget.chatId,
            currentUserId: currentUserId,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Delete failed: $e');
      }
    }
  }

  String? _otherParticipantId(ChatModel? chat) {
    final currentUserId = _currentUserId();
    if (chat == null || chat.isGroup || currentUserId == null) return null;
    return chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  Future<void> _setMediaPermission(bool enabled) async {
    final currentUserId = _currentUserId();
    if (currentUserId == null) return;
    await ref.read(chatRepositoryProvider).updateGroupInfo(widget.chatId, {
      'mediaPermissions.$currentUserId': enabled,
    });
  }

  Future<void> _setBlocked(bool blocked) async {
    final currentUserId = _currentUserId();
    if (currentUserId == null) return;
    await ref.read(chatRepositoryProvider).updateGroupInfo(widget.chatId, {
      'blockedBy': blocked
          ? FieldValue.arrayUnion([currentUserId])
          : FieldValue.arrayRemove([currentUserId]),
    });
  }

  Future<void> _showChatActions(ChatModel? chat) async {
    final currentUserId = _currentUserId();
    final mediaEnabled = currentUserId != null
        ? (chat?.mediaPermissions[currentUserId] ?? true)
        : true;
    final isBlocked = currentUserId != null
        ? (chat?.blockedBy.contains(currentUserId) ?? false)
        : false;
    final otherUserId = _otherParticipantId(chat);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (otherUserId != null && otherUserId.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.textSecondary,
                ),
                title: const Text(
                  'View profile',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/profile/$otherUserId');
                },
              ),
            ListTile(
              leading: const Icon(Icons.search, color: AppColors.textSecondary),
              title: const Text(
                'Search in chat',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _openInChatSearch();
              },
            ),
            SwitchListTile(
              secondary: const Icon(
                Icons.perm_media_outlined,
                color: AppColors.textSecondary,
              ),
              title: const Text(
                'Allow media sending',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              value: mediaEnabled,
              onChanged: (value) async {
                await _setMediaPermission(value);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            if (otherUserId != null && otherUserId.isNotEmpty)
              ListTile(
                leading: Icon(
                  isBlocked ? Icons.lock_open_outlined : Icons.block,
                  color: isBlocked ? AppColors.textSecondary : AppColors.error,
                ),
                title: Text(
                  isBlocked ? 'Unblock user' : 'Block user',
                  style: TextStyle(
                    color: isBlocked ? AppColors.textPrimary : AppColors.error,
                  ),
                ),
                onTap: () async {
                  await _setBlocked(!isBlocked);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.textSecondary,
              ),
              title: const Text(
                'Delete conversation for me',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _deleteConversationForMe();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete conversation for everyone',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _deleteConversationForEveryone();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) return;

    final currentUserId = _currentUserId();
    final chat = await ref.read(chatInfoProvider(widget.chatId).future);
    if (chat != null && currentUserId != null) {
      final blocked = chat.blockedBy.contains(currentUserId);
      final mediaEnabled = chat.mediaPermissions[currentUserId] ?? true;
      if (blocked) {
        if (mounted) AppSnackBar.error(context, 'Conversation is blocked.');
        return;
      }
      if (_selectedImageBytes != null && !mediaEnabled) {
        if (mounted) {
          AppSnackBar.error(context, 'Media sending is disabled in settings.');
        }
        return;
      }
    }

    _messageController.clear();
    final imageBytes = _selectedImageBytes;
    setState(() {
      _selectedImageBytes = null;
      _isUploading = imageBytes != null;
    });

    try {
      final user = await ref.read(currentUserProfileProvider.future);
      if (user == null) return;

      String? imageUrl;
      if (imageBytes != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        imageUrl = await CloudinaryService.uploadImage(
          imageBytes: imageBytes,
          fileName: 'chat_${widget.chatId}_$timestamp.jpg',
          folder: 'archives/chats',
        );
      }

      if (mounted) setState(() => _isUploading = false);

      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            chatId: widget.chatId,
            sender: user,
            content: text.isNotEmpty
                ? text
                : (imageUrl != null ? '📷 Photo' : ''),
            imageUrl: imageUrl,
          );

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        AppSnackBar.error(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final effectiveCurrentUserId =
        widget.currentUserIdOverride ?? currentUser?.uid;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final chatInfoAsync = ref.watch(chatInfoProvider(widget.chatId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedMessageIds.clear()),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
        title: chatInfoAsync.when(
          data: (chat) {
            if (chat == null) return const Text('Chat');
            if (chat.isGroup) {
              return Text(chat.groupName ?? 'Group Chat');
            }
            // 1-to-1: show other user's name
            final otherUserId = chat.participants.firstWhere(
              (id) => id != effectiveCurrentUserId,
              orElse: () => '',
            );
            if (otherUserId.isEmpty) return const Text('Chat');

            final otherUser = ref.watch(userProfileProvider(otherUserId));
            return otherUser.when(
              data: (user) => Row(
                children: [
                  AvatarWidget(
                    imageUrl: user?.profilePhoto,
                    name: user?.name ?? 'User',
                    radius: 16,
                  ),
                  const SizedBox(width: 10),
                  Text(user?.name ?? 'User'),
                ],
              ),
              loading: () => const Text('Loading...'),
              error: (_, _) => const Text('Chat'),
            );
          },
          loading: () => const Text('Loading...'),
          error: (_, _) => const Text('Chat'),
        ),
        surfaceTintColor: Colors.transparent,
        actions: _isSelectionMode
            ? [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      '${_selectedMessageIds.length}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete selected',
                  onPressed: _deleteSelectedMessages,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  tooltip: 'Send image',
                  onPressed: _isUploading ? null : _pickImage,
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Chat options',
                  onPressed: () => _showChatActions(chatInfoAsync.valueOrNull),
                ),
              ],
      ),
      body: ColoredBox(
        color: AppColors.background,
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  _syncSeenStatusIfNeeded(messages, effectiveCurrentUserId);

                  final initialTarget = widget.highlightedMessageId;
                  if (!_initialJumpHandled &&
                      initialTarget != null &&
                      initialTarget.isNotEmpty) {
                    _initialJumpHandled = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _jumpToMessage(initialTarget, messages, context);
                    });
                  }

                  if (_pendingJumpMessageId != null) {
                    final pendingTarget = _pendingJumpMessageId!;
                    _pendingJumpMessageId = null;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _jumpToMessage(pendingTarget, messages, context);
                    });
                  }

                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet. Say hello!',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    );
                  }

                  return ColoredBox(
                    color: AppColors.background,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == effectiveCurrentUserId;

                        return _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          showAvatar: false,
                          isSelected: _selectedMessageIds.contains(msg.id),
                          isHighlighted: _activeHighlightMessageId == msg.id,
                          onTap: _isSelectionMode
                              ? () => _toggleMessageSelection(msg, isMe)
                              : null,
                          onLongPress: () {
                            if (_isSelectionMode) {
                              _toggleMessageSelection(msg, isMe);
                              return;
                            }

                            _showMessageActions(msg, isMe);
                          },
                          reactionsFooter: _buildReactionChips(msg),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
            // Image preview
            if (_selectedImageBytes != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                color: AppColors.surface,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _selectedImageBytes!,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _removeImage,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Uploading indicator
            if (_isUploading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: AppColors.surface,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Uploading image...',
                      style: TextStyle(color: AppColors.textHint, fontSize: 13),
                    ),
                  ],
                ),
              ),
            // Input bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: const TextStyle(color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.7),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 100,
                        maxWidth: 100,
                      ),
                      prefixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 40,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.emoji_emotions_outlined,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: _isUploading
                                ? null
                                : _openComposerEmojiPicker,
                            tooltip: 'Add emoji',
                          ),
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 40,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.image_outlined,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: _isUploading ? null : _pickImage,
                            tooltip: 'Send image',
                          ),
                        ],
                      ),
                      suffixIcon: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: _isUploading
                              ? AppColors.surface
                              : AppColors.accent,
                          foregroundColor: _isUploading
                              ? AppColors.textHint
                              : Colors.white,
                        ),
                        icon: const Icon(Icons.send),
                        onPressed: _isUploading ? null : _sendMessage,
                        tooltip: 'Send message',
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? reactionsFooter;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onTap,
    this.onLongPress,
    this.reactionsFooter,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppColors.accentBeige : AppColors.cardBackground;
    final messageTextColor = isMe ? AppColors.inkDark : AppColors.textPrimary;
    final metaTextColor = isMe
        ? AppColors.inkDark.withValues(alpha: 0.7)
        : AppColors.textHint;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      border: Border.all(
                        color: isHighlighted
                            ? AppColors.secondaryAccent
                            : isSelected
                            ? AppColors.border.withValues(alpha: 0.65)
                            : Colors.transparent,
                        width: isHighlighted || isSelected ? 1.5 : 0,
                      ),
                      boxShadow: [
                        if (isHighlighted || isSelected)
                          BoxShadow(
                            color:
                                (isHighlighted
                                        ? AppColors.secondaryAccent
                                        : AppColors.border)
                                    .withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                      ],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Image display
                        if (message.imageUrl != null &&
                            message.imageUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: message.imageUrl!,
                                maxWidthDiskCache: 600,
                                placeholder: (_, _) => Container(
                                  height: 150,
                                  width: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  height: 150,
                                  width: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Text content (skip placeholder for image-only active message)
                        if (message.content.isNotEmpty &&
                            message.content != '📷 Photo')
                          Text(
                            message.content,
                            style: TextStyle(
                              fontStyle: message.isDeleted
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: messageTextColor,
                              fontSize: 15,
                            ),
                          )
                        else if (message.imageUrl == null ||
                            message.imageUrl!.isEmpty)
                          Text(
                            message.content,
                            style: TextStyle(
                              fontStyle: message.isDeleted
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: messageTextColor,
                              fontSize: 15,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeago.format(
                                message.createdAt,
                                locale: 'en_short',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: metaTextColor,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.status == MessageStatus.seen
                                    ? Icons.done_all
                                    : message.status == MessageStatus.delivered
                                    ? Icons.done_all
                                    : Icons.done,
                                size: 14,
                                color: message.status == MessageStatus.seen
                                    ? Colors.blue[200]
                                    : metaTextColor,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (reactionsFooter != null)
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: isMe ? 0 : 10,
                right: isMe ? 10 : 0,
              ),
              child: reactionsFooter,
            ),
        ],
      ),
    );
  }
}
