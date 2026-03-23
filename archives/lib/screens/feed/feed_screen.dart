import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/interaction_gate.dart';
import '../../core/share/post_share_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../widgets/common/branded_state_view.dart';
import '../../widgets/common/skeletons.dart';
import '../../widgets/post/post_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  Future<void> _sharePost(BuildContext context, String postId) async {
    try {
      await PostShareService.sharePostUrl(postId);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share this post right now.')),
      );
    }
  }

  void _showPostOptions(BuildContext context, WidgetRef ref, String postId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive Post'),
              subtitle: const Text('Hide from feed. You can unarchive later.'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(postRepositoryProvider).archivePost(postId);
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
                _confirmDelete(context, ref, postId);
              },
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
                    onRepostTap: () =>
                        context.push('/create-post?repostId=${post.id}'),
                    onShareTap: () => _sharePost(context, post.id),
                    onMenuTap: isOwn
                        ? () {
                            HapticFeedback.selectionClick();
                            _showPostOptions(context, ref, post.id);
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
