import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/interaction_intent.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../core/navigation/interaction_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/web_image_picker.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/user_providers.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/branded_state_view.dart';
import '../../widgets/common/skeletons.dart';
import '../../widgets/post/post_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  Future<List<UserModel>> _loadTaggableUsers(WidgetRef ref) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return const [];

    final userRepo = ref.read(userRepositoryProvider);
    final following = await userRepo.getFollowing(currentUser.uid);
    final followers = await userRepo.getFollowers(currentUser.uid);

    final followingIds = following.map((e) => e.followingId).toSet();
    final followerIds = followers.map((e) => e.followerId).toSet();

    final candidateIds = <String>{...followingIds, ...followerIds}
      ..remove(currentUser.uid);

    final users = <UserModel>[];
    for (final uid in candidateIds) {
      final user = await userRepo.getUserById(uid);
      if (user == null) continue;
      final canTag = followerIds.contains(uid) || !user.isPrivate;
      if (canTag) {
        users.add(user);
      }
    }

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  void _showPostOptions(BuildContext context, WidgetRef ref, PostModel post) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Post'),
              subtitle: const Text('Edit caption, files, privacy, and tags'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditPostDialog(context, ref, post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive Post'),
              subtitle: const Text('Hide from feed. You can unarchive later.'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(postRepositoryProvider).archivePost(post.id);
                ref.read(feedProvider.notifier).refresh();
                if (context.mounted) {
                  AppSnackBar.success(context, 'Post archived.');
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text('Delete Post'),
              subtitle: const Text('Permanently delete this post'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, post.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPostDialog(
    BuildContext context,
    WidgetRef ref,
    PostModel post,
  ) {
    final controller = TextEditingController(text: post.content);
    PostPrivacy privacy = post.privacy;
    final tags = [...post.tags];
    final imageUrls = [...post.allImageUrls];
    final videoUrls = [...post.videoUrls];
    final fileUrls = [...post.fileUrls];

    final newImages = <({Uint8List bytes, String name})>[];
    final newVideos = <({Uint8List bytes, String name})>[];
    final newFiles = <({Uint8List bytes, String name})>[];
    var isSaving = false;

    Future<List<String>> uploadBatch({
      required List<({Uint8List bytes, String name})> items,
      required Future<String?> Function(Uint8List bytes, String name) uploader,
    }) async {
      final urls = <String>[];
      for (final item in items) {
        final url = await uploader(item.bytes, item.name);
        if (url != null && url.trim().isNotEmpty) {
          urls.add(url.trim());
        }
      }
      return urls;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickImages() async {
            final picked = await pickImagesFromBrowser();
            if (picked.isEmpty) return;
            setDialogState(() => newImages.addAll(picked));
          }

          Future<void> pickVideo() async {
            final (bytes, name, _) = await pickVideoFromBrowser();
            if (bytes == null || name == null) return;
            if (!name.toLowerCase().endsWith('.mp4')) {
              if (context.mounted) {
                AppSnackBar.error(context, 'Only mp4 videos are supported.');
              }
              return;
            }
            setDialogState(() => newVideos.add((bytes: bytes, name: name)));
          }

          Future<void> pickFiles() async {
            final picked = await pickFilesFromBrowser();
            if (picked.isEmpty) return;
            setDialogState(() => newFiles.addAll(picked));
          }

          Future<void> saveEdits() async {
            if (isSaving) return;
            isSaving = true;
            setDialogState(() {});

            try {
              final uploadedImages = await uploadBatch(
                items: newImages,
                uploader: (bytes, name) => CloudinaryService.uploadImage(
                  imageBytes: bytes,
                  fileName: name,
                  folder: 'archives/posts/images',
                ),
              );
              final uploadedVideos = await uploadBatch(
                items: newVideos,
                uploader: (bytes, name) => CloudinaryService.uploadVideo(
                  videoBytes: bytes,
                  fileName: name,
                  folder: 'archives/posts/videos',
                ),
              );
              final uploadedFiles = await uploadBatch(
                items: newFiles,
                uploader: (bytes, name) => CloudinaryService.uploadRawFile(
                  fileBytes: bytes,
                  fileName: name,
                  folder: 'archives/posts/files',
                ),
              );

              final mergedImages = [...imageUrls, ...uploadedImages];
              final mergedVideos = [...videoUrls, ...uploadedVideos];
              final mergedFiles = [...fileUrls, ...uploadedFiles];

              await ref.read(postRepositoryProvider).updatePost(post.id, {
                'content': controller.text.trim(),
                'privacy': privacy.name,
                'tags': tags,
                'imageUrl': mergedImages.isEmpty ? null : mergedImages.first,
                'imageUrls': mergedImages,
                'videoUrls': mergedVideos,
                'fileUrls': mergedFiles,
              });

              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              ref.read(feedProvider.notifier).refresh();
              if (context.mounted) {
                AppSnackBar.success(context, 'Post updated.');
              }
            } catch (e) {
              if (context.mounted) {
                AppSnackBar.error(context, 'Update failed: $e');
              }
            } finally {
              isSaving = false;
              if (ctx.mounted) {
                setDialogState(() {});
              }
            }
          }

          final canSave = controller.text.trim().isNotEmpty;

          return AlertDialog(
            title: const Text('Edit Post'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 8,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Update your post caption',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PostPrivacy>(
                      initialValue: privacy,
                      items: const [
                        DropdownMenuItem(
                          value: PostPrivacy.public,
                          child: Text('Public'),
                        ),
                        DropdownMenuItem(
                          value: PostPrivacy.followersOnly,
                          child: Text('Followers only'),
                        ),
                        DropdownMenuItem(
                          value: PostPrivacy.onlyMe,
                          child: Text('Only me'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => privacy = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Privacy',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Tag users',
                          onPressed: () async {
                            final users = await _loadTaggableUsers(ref);
                            if (!context.mounted) return;
                            if (users.isEmpty) {
                              AppSnackBar.error(
                                context,
                                'No users available to tag right now.',
                              );
                              return;
                            }

                            final picked =
                                await showModalBottomSheet<List<String>>(
                                  context: context,
                                  isScrollControlled: true,
                                  showDragHandle: true,
                                  backgroundColor: AppColors.surface,
                                  builder: (sheetCtx) =>
                                      _EditTaggableUsersSheet(
                                        users: users,
                                        initialTags: tags,
                                      ),
                                );
                            if (picked == null) return;
                            setDialogState(() {
                              tags
                                ..clear()
                                ..addAll(picked);
                            });
                          },
                          icon: const Icon(Icons.alternate_email_rounded),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tag followers and public accounts you follow',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...tags.map(
                          (tag) => InputChip(
                            label: Text('@$tag'),
                            onDeleted: () {
                              setDialogState(() => tags.remove(tag));
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.photo_library_outlined),
                          label: const Text('Add images'),
                          onPressed: pickImages,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.videocam_outlined),
                          label: const Text('Add video'),
                          onPressed: pickVideo,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.attach_file),
                          label: const Text('Add file'),
                          onPressed: pickFiles,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...imageUrls.map(
                          (url) => InputChip(
                            label: const Text('Image'),
                            onDeleted: () {
                              setDialogState(() => imageUrls.remove(url));
                            },
                          ),
                        ),
                        ...videoUrls.map(
                          (url) => InputChip(
                            label: const Text('Video'),
                            onDeleted: () {
                              setDialogState(() => videoUrls.remove(url));
                            },
                          ),
                        ),
                        ...fileUrls.map(
                          (url) => InputChip(
                            label: const Text('File'),
                            onDeleted: () {
                              setDialogState(() => fileUrls.remove(url));
                            },
                          ),
                        ),
                        ...newImages.map(
                          (item) => InputChip(
                            label: Text('New image: ${item.name}'),
                            onDeleted: () {
                              setDialogState(() => newImages.remove(item));
                            },
                          ),
                        ),
                        ...newVideos.map(
                          (item) => InputChip(
                            label: Text('New video: ${item.name}'),
                            onDeleted: () {
                              setDialogState(() => newVideos.remove(item));
                            },
                          ),
                        ),
                        ...newFiles.map(
                          (item) => InputChip(
                            label: Text('New file: ${item.name}'),
                            onDeleted: () {
                              setDialogState(() => newFiles.remove(item));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: !canSave || isSaving ? null : saveEdits,
                child: isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSendPostSheet(
    BuildContext context,
    WidgetRef ref,
    PostModel post,
  ) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) {
      await ensureAuthenticatedForIntent(
        context: context,
        ref: ref,
        intent: InteractionIntent(
          targetType: InteractionTargetType.post,
          targetId: post.id,
          action: InteractionAction.share,
        ),
      );
      return;
    }

    final following = await ref
        .read(userRepositoryProvider)
        .getFollowing(currentUser.uid);

    final followingUsers = <UserModel>[];
    for (final item in following) {
      final user = await ref
          .read(userRepositoryProvider)
          .getUserById(item.followingId);
      if (user != null) {
        followingUsers.add(user);
      }
    }

    if (!context.mounted) return;

    if (followingUsers.isEmpty) {
      if (context.mounted) {
        AppSnackBar.error(context, 'Follow users first to send this post.');
      }
      return;
    }

    final sharedChatId = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) =>
          _PostShareSheet(post: post, followingUsers: followingUsers),
    );

    if (sharedChatId != null && context.mounted) {
      context.push('/chat/$sharedChatId');
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(postRepositoryProvider).deletePost(postId);
              ref.read(feedProvider.notifier).refresh();
              if (context.mounted) {
                AppSnackBar.success(context, 'Post deleted.');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReportMenu(BuildContext context, WidgetRef ref, String postId) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report Post'),
              onTap: () async {
                Navigator.pop(ctx);
                final canOpen = await ensureAuthenticatedForPath(
                  context: context,
                  ref: ref,
                  destinationPath: '/report/post/$postId',
                );
                if (!canOpen || !context.mounted) return;
                context.push('/report/post/$postId');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedProvider);
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.uid;
    final isGuest = currentUserId == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('For You'),
        centerTitle: false,
        actions: [
          if (!isGuest)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
              onPressed: () => context.push('/activity'),
            ),
        ],
      ),
      body: feedState.when(
        data: (posts) {
          if (posts.isEmpty) {
            return BrandedStateView(
              icon: Icons.article_outlined,
              title: 'No posts yet',
              subtitle: 'Be the first to post something.',
              action: ElevatedButton(
                onPressed: () async {
                  final canOpen = await ensureAuthenticatedForPath(
                    context: context,
                    ref: ref,
                    destinationPath: '/create-post',
                  );
                  if (!canOpen || !context.mounted) return;
                  context.push('/create-post');
                },
                child: const Text('Create Post'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(feedProvider.notifier).refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter < 200) {
                  ref.read(feedProvider.notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                itemCount: posts.length,
                separatorBuilder: (_, index) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final isOwn = post.userId == currentUserId;
                  return PostCard(
                    post: post,
                    preferUsernameInHeader: true,
                    onTap: () async {
                      final canOpen = await ensureAuthenticatedForPath(
                        context: context,
                        ref: ref,
                        destinationPath: '/post/${post.id}',
                      );
                      if (!canOpen || !context.mounted) return;
                      context.push('/post/${post.id}');
                    },
                    onProfileTap: () => context.push('/profile/${post.userId}'),
                    onCommentTap: () =>
                        context.push('/post/${post.id}?focus=comments'),
                    onSendTap: () => _openSendPostSheet(context, ref, post),
                    onMenuTap: isOwn
                        ? () {
                            HapticFeedback.selectionClick();
                            _showPostOptions(context, ref, post);
                          }
                        : () => _showReportMenu(context, ref, post.id),
                  );
                },
              ),
            ),
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: 4,
          itemBuilder: (context, index) => PostCardSkeleton(delay: index * 80),
        ),
        error: (e, _) => BrandedStateView(
          icon: Icons.error_outline,
          title: 'Feed unavailable',
          subtitle: '$e',
          action: ElevatedButton(
            onPressed: () => ref.read(feedProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}

class _PostShareSheet extends ConsumerStatefulWidget {
  final PostModel post;
  final List<UserModel> followingUsers;

  const _PostShareSheet({required this.post, required this.followingUsers});

  @override
  ConsumerState<_PostShareSheet> createState() => _PostShareSheetState();
}

class _EditTaggableUsersSheet extends StatefulWidget {
  final List<UserModel> users;
  final List<String> initialTags;

  const _EditTaggableUsersSheet({
    required this.users,
    required this.initialTags,
  });

  @override
  State<_EditTaggableUsersSheet> createState() =>
      _EditTaggableUsersSheetState();
}

class _EditTaggableUsersSheetState extends State<_EditTaggableUsersSheet> {
  late final Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTags.map((e) => e.trim()).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.users.where((user) {
      if (_query.trim().isEmpty) return true;
      final needle = _query.trim().toLowerCase();
      return user.name.toLowerCase().contains(needle) ||
          user.username.toLowerCase().contains(needle);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search users to tag',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final user = filtered[index];
                  final isSelected = _selected.contains(user.username);

                  return CheckboxListTile(
                    value: isSelected,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(user.name),
                    subtitle: Text('@${user.username}'),
                    onChanged: (_) {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(user.username);
                        } else {
                          _selected.add(user.username);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context, _selected.toList()..sort());
                },
                child: const Text('Apply tags'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostShareSheetState extends ConsumerState<_PostShareSheet> {
  String _query = '';
  String? _sendingToUserId;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.followingUsers.where((u) {
      if (_query.trim().isEmpty) return true;
      final needle = _query.trim().toLowerCase();
      return u.name.toLowerCase().contains(needle) ||
          u.username.toLowerCase().contains(needle);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Send to followed user...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = filtered[index];
                  final isSending = _sendingToUserId == user.uid;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.username),
                    trailing: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    onTap: isSending
                        ? null
                        : () async {
                            final currentUser = ref
                                .read(authStateProvider)
                                .valueOrNull;
                            if (currentUser == null) return;

                            final sender = await ref.read(
                              currentUserProfileProvider.future,
                            );
                            if (sender == null) return;

                            setState(() => _sendingToUserId = user.uid);
                            try {
                              final chatId = await ref
                                  .read(chatRepositoryProvider)
                                  .getOrCreateDirectChat(
                                    currentUser.uid,
                                    user.uid,
                                  );

                              final marker = '/post/${widget.post.id}';
                              final previousShares = await ref
                                  .read(chatRepositoryProvider)
                                  .searchMessagesInChat(
                                    chatId: chatId,
                                    query: marker,
                                    currentUserId: currentUser.uid,
                                    limit: 20,
                                  );

                              final alreadyShared = previousShares.any(
                                (message) => message.snippet.contains(marker),
                              );
                              if (alreadyShared) {
                                if (context.mounted) {
                                  AppSnackBar.info(
                                    context,
                                    'This post was already shared in this chat.',
                                  );
                                  Navigator.pop(context, chatId);
                                }
                                return;
                              }

                              await ref
                                  .read(chatRepositoryProvider)
                                  .sendMessage(
                                    chatId: chatId,
                                    sender: sender,
                                    content:
                                        'Shared a post with you: /post/${widget.post.id}\n\n${widget.post.content}',
                                    imageUrl: widget.post.primaryImageUrl,
                                  );

                              if (context.mounted) {
                                Navigator.pop(context, chatId);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackBar.error(
                                  context,
                                  'Failed to send: $e',
                                );
                              }
                              setState(() => _sendingToUserId = null);
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
