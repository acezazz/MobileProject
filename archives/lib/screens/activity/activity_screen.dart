import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/post_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/common/branded_state_view.dart';

final activityItemsProvider = FutureProvider<List<_ActivityItem>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final userRepo = ref.read(userRepositoryProvider);
  final postRepo = ref.read(postRepositoryProvider);

  final followers = await userRepo.getFollowers(user.uid);
  final posts = await postRepo.getUserPosts(userId: user.uid, limit: 50);

  final followerUsers = await Future.wait(
    followers.take(30).map((f) => userRepo.getUserById(f.followerId)),
  );

  final items = <_ActivityItem>[];

  for (var i = 0; i < followerUsers.length; i++) {
    final follower = followers[i];
    final followerUser = followerUsers[i];
    final username = followerUser?.username ?? 'someone';
    final name = followerUser?.name ?? 'Someone';
    items.add(
      _ActivityItem(
        type: _ActivityType.follow,
        title: '$name started following you',
        subtitle: '@$username',
        createdAt: follower.createdAt,
        icon: Icons.person_add_alt_1,
        targetUserId: follower.followerId,
      ),
    );
  }

  final candidatePosts = posts.take(50).toList();
  final counts = await Future.wait(
    candidatePosts.map((post) => postRepo.getPostInteractionCounts(post.id)),
  );

  for (var i = 0; i < candidatePosts.length; i++) {
    final post = candidatePosts[i];
    final likeCount = counts[i].likesCount;
    final commentCount = counts[i].commentsCount;
    if (likeCount <= 0 && commentCount <= 0) continue;
    items.add(
      _postActivityItem(
        post,
        likesCount: likeCount,
        commentsCount: commentCount,
      ),
    );
  }

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
});

_ActivityItem _postActivityItem(
  PostModel post, {
  required int likesCount,
  required int commentsCount,
}) {
  final details = <String>[];
  if (likesCount > 0) details.add('$likesCount likes');
  if (commentsCount > 0) details.add('$commentsCount comments');

  return _ActivityItem(
    type: _ActivityType.postInteraction,
    title: 'Your post received ${details.join(' and ')}',
    subtitle: post.content.isEmpty
        ? 'Tap to view post details'
        : post.content.length > 58
        ? '${post.content.substring(0, 58)}...'
        : post.content,
    createdAt: post.createdAt,
    icon: Icons.favorite_border,
    targetPostId: post.id,
  );
}

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: activity.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BrandedStateView(
          icon: Icons.error_outline,
          title: 'Notifications unavailable',
          subtitle: '$e',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const BrandedStateView(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              subtitle: 'Likes, comments, and followers will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(activityItemsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final timestamp = timeago.format(item.createdAt);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    onTap: () {
                      if (item.type == _ActivityType.postInteraction) {
                        if (item.targetPostId != null) {
                          context.push(
                            '/post/${item.targetPostId}?focus=comments',
                          );
                        }
                        return;
                      }
                      if (item.targetUserId != null) {
                        context.push('/profile/${item.targetUserId}');
                      }
                    },
                    leading: CircleAvatar(child: Icon(item.icon, size: 20)),
                    title: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text('${item.subtitle}\n$timestamp'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ActivityItem {
  final _ActivityType type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final IconData icon;
  final String? targetUserId;
  final String? targetPostId;

  const _ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.icon,
    this.targetUserId,
    this.targetPostId,
  });
}

enum _ActivityType { follow, postInteraction }
