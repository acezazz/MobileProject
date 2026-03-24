import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../core/navigation/interaction_gate.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../widgets/common/branded_state_view.dart';
import '../../widgets/common/skeletons.dart';
import '../../widgets/post/post_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  void _showPostOptions(BuildContext context, WidgetRef ref, PostModel post) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Post'),
              subtitle: const Text('Update your post content'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post archived')),
                  );
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
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Post'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 8,
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
            decoration: const InputDecoration(
              hintText: 'Update your post',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () async {
                      final newContent = controller.text.trim();
                      Navigator.pop(ctx);
                      try {
                        await ref.read(postRepositoryProvider).updatePost(
                          post.id,
                          {'content': newContent},
                        );
                        ref.read(feedProvider.notifier).refresh();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Post updated')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Update failed: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Post deleted')));
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
        title: const Text('Home'),
        actions: [
          if (!isGuest)
            IconButton(
              icon: const Icon(Icons.chat_outlined),
              onPressed: () => context.push('/chats'),
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
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                itemCount: posts.length,
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
          itemCount: 5,
          itemBuilder: (context, index) => const PostCardSkeleton(),
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
