import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  final following = await userRepo.getFollowing(user.uid);
  final followingIds = following.map((f) => f.followingId).toSet();
  final posts = await postRepo.getUserPosts(userId: user.uid, limit: 50);

  final followerUsers = await Future.wait(
    followers.take(30).map((f) => userRepo.getUserById(f.followerId)),
  );

  final items = <_ActivityItem>[];

  final moderationNotifications = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .get();

  for (final doc in moderationNotifications.docs) {
    final data = doc.data();
    final type = (data['type'] ?? '').toString();
    if (type != 'warning' && type != 'suspension') {
      continue;
    }

    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();

    items.add(
      _ActivityItem(
        type: _ActivityType.moderation,
        title: (data['title'] ?? 'Moderation update').toString(),
        subtitle: (data['message'] ?? '').toString(),
        createdAt: createdAt,
        icon: type == 'suspension'
            ? Icons.gpp_bad_outlined
            : Icons.warning_amber_rounded,
        targetPostId: (data['postId'] ?? '').toString().trim().isEmpty
            ? null
            : (data['postId'] ?? '').toString().trim(),
      ),
    );
  }

  for (var i = 0; i < followerUsers.length; i++) {
    final follower = followers[i];
    final followerUser = followerUsers[i];
    final username = followerUser?.username ?? 'someone';
    final name = followerUser?.name ?? 'Someone';
    final isFollowBack = followingIds.contains(follower.followerId);

    items.add(
      _ActivityItem(
        type: isFollowBack
            ? _ActivityType.followBack
            : _ActivityType.newFollowing,
        title: isFollowBack
            ? '$name followed you back'
            : '$name started following you',
        subtitle: '@$username',
        createdAt: follower.createdAt,
        icon: isFollowBack ? Icons.sync_alt : Icons.person_add_alt_1,
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
    if (likeCount > 0) {
      items.add(
        _ActivityItem(
          type: _ActivityType.likeComment,
          title: 'Your post received $likeCount likes',
          subtitle: post.content.isEmpty
              ? 'Tap to view post details'
              : post.content.length > 58
              ? '${post.content.substring(0, 58)}...'
              : post.content,
          createdAt: post.createdAt,
          icon: Icons.favorite_border,
          targetPostId: post.id,
        ),
      );
    }
    if (commentCount > 0) {
      items.add(
        _ActivityItem(
          type: _ActivityType.likeComment,
          title: 'Your post received $commentCount comments',
          subtitle: post.content.isEmpty
              ? 'Tap to view post details'
              : post.content.length > 58
              ? '${post.content.substring(0, 58)}...'
              : post.content,
          createdAt: post.createdAt,
          icon: Icons.mode_comment_outlined,
          targetPostId: post.id,
        ),
      );
    }
  }

  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
});

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;

  List<_ActivityItem> _applyFilter(List<_ActivityItem> items) {
    switch (_filter) {
      case _NotificationFilter.all:
        return items;
      case _NotificationFilter.likeComment:
        return items.where((i) => i.type == _ActivityType.likeComment).toList();
      case _NotificationFilter.newFollowing:
        return items
            .where((i) => i.type == _ActivityType.newFollowing)
            .toList();
      case _NotificationFilter.followBack:
        return items.where((i) => i.type == _ActivityType.followBack).toList();
      case _NotificationFilter.moderation:
        return items.where((i) => i.type == _ActivityType.moderation).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          final filtered = _applyFilter(items);
          if (items.isEmpty) {
            return const BrandedStateView(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              subtitle: 'Likes, comments, and followers will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(activityItemsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == _NotificationFilter.all,
                      onSelected: (_) {
                        setState(() => _filter = _NotificationFilter.all);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Likes/Comments'),
                      selected: _filter == _NotificationFilter.likeComment,
                      onSelected: (_) {
                        setState(
                          () => _filter = _NotificationFilter.likeComment,
                        );
                      },
                    ),
                    ChoiceChip(
                      label: const Text('New Following'),
                      selected: _filter == _NotificationFilter.newFollowing,
                      onSelected: (_) {
                        setState(
                          () => _filter = _NotificationFilter.newFollowing,
                        );
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Followback'),
                      selected: _filter == _NotificationFilter.followBack,
                      onSelected: (_) {
                        setState(
                          () => _filter = _NotificationFilter.followBack,
                        );
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Moderation'),
                      selected: _filter == _NotificationFilter.moderation,
                      onSelected: (_) {
                        setState(
                          () => _filter = _NotificationFilter.moderation,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: BrandedStateView(
                      icon: Icons.filter_alt_off,
                      title: 'No notifications in this filter',
                      subtitle: 'Try selecting a different filter.',
                    ),
                  )
                else
                  ...filtered.map((item) {
                    final timestamp = timeago.format(item.createdAt);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        onTap: () {
                          if (item.type == _ActivityType.likeComment) {
                            if (item.targetPostId != null) {
                              context.push(
                                '/post/${item.targetPostId}?focus=comments',
                              );
                            }
                            return;
                          }
                          if (item.type == _ActivityType.moderation) {
                            if (item.targetPostId != null) {
                              context.push('/post/${item.targetPostId}');
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
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${item.subtitle}\n$timestamp'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  }),
              ],
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

enum _ActivityType { likeComment, newFollowing, followBack, moderation }

enum _NotificationFilter {
  all,
  likeComment,
  newFollowing,
  followBack,
  moderation,
}
