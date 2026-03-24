import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/interaction_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../models/post_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/user_providers.dart';
import '../../providers/post_providers.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/skeletons.dart';
import '../../widgets/post/post_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  void _refreshProfilePosts() {
    ref.invalidate(userPostsProvider(widget.userId));
    ref.invalidate(userArchivedPostsProvider(widget.userId));
  }

  void _showPostOptions(BuildContext context, PostModel post) {
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
                _showEditPostDialog(context, post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive Post'),
              subtitle: const Text('Hide from feed. You can unarchive later.'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(postRepositoryProvider).archivePost(post.id);
                _refreshProfilePosts();
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
                _confirmDelete(context, post.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPostDialog(BuildContext context, PostModel post) {
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
                        _refreshProfilePosts();
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

  void _confirmDelete(BuildContext context, String postId) {
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
              _refreshProfilePosts();
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

  void _showReportMenu(BuildContext context, String postId) {
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isOwnProfile = currentUser?.uid == widget.userId;
    final isFollowingProfileOwner = isOwnProfile
        ? true
        : (currentUser == null
              ? false
              : (ref
                        .watch(
                          isFollowingProvider((
                            currentUserId: currentUser.uid,
                            targetUserId: widget.userId,
                          )),
                        )
                        .valueOrNull ??
                    false));

    final profileAsync = ref.watch(userProfileStreamProvider(widget.userId));
    final postsAsync = ref.watch(userPostsProvider(widget.userId));
    final archivedPostsAsync = ref.watch(
      userArchivedPostsProvider(widget.userId),
    );
    final followersCountAsync = ref.watch(
      followersCountProvider(widget.userId),
    );
    final followingCountAsync = ref.watch(
      followingCountProvider(widget.userId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (isOwnProfile) ...[
            IconButton(
              onPressed: () => context.push('/my-archives'),
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archived posts',
            ),
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ] else
            IconButton(
              onPressed: () => context.push('/report/user/${widget.userId}'),
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => ListView.builder(
          itemCount: 4,
          itemBuilder: (context, index) => const PostCardSkeleton(),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          final followersCount =
              followersCountAsync.valueOrNull ?? user.followersCount;
          final followingCount =
              followingCountAsync.valueOrNull ?? user.followingCount;
          final visiblePostsCount = _visiblePosts(
            postsAsync.valueOrNull ?? const <PostModel>[],
            isOwnProfile: isOwnProfile,
            isFollowingProfileOwner: isFollowingProfileOwner,
          ).length;
          final visibleArchivedCount = _visiblePosts(
            archivedPostsAsync.valueOrNull ?? const <PostModel>[],
            isOwnProfile: isOwnProfile,
            isFollowingProfileOwner: isFollowingProfileOwner,
          ).length;
          final totalVisiblePosts = visiblePostsCount + visibleArchivedCount;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileStreamProvider(widget.userId));
              ref.invalidate(userPostsProvider(widget.userId));
              ref.invalidate(followersCountProvider(widget.userId));
              ref.invalidate(followingCountProvider(widget.userId));
            },
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 460),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final clamped = value.clamp(0.0, 1.0);
                        return Transform.translate(
                          offset: Offset(0, (1 - clamped) * 18),
                          child: Opacity(opacity: clamped, child: child),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AvatarWidget(
                                    imageUrl: user.profilePhoto,
                                    name: user.name,
                                    radius: 42,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                          ),
                                          child: Text(
                                            '@${user.username}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (user.bio.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  user.bio,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(height: 1.35),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Posts',
                                      value: '$totalVisiblePosts',
                                      onTap: () => _tabController.animateTo(0),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Followers',
                                      value: '$followersCount',
                                      onTap: () => context.push(
                                        '/followers/${widget.userId}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatCard(
                                      label: 'Following',
                                      value: '$followingCount',
                                      onTap: () => context.push(
                                        '/following/${widget.userId}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: isOwnProfile
                                    ? OutlinedButton.icon(
                                        onPressed: () =>
                                            context.push('/edit-profile'),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Edit profile'),
                                      )
                                    : _FollowButton(
                                        currentUserId: currentUser?.uid ?? '',
                                        targetUserId: widget.userId,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        unselectedLabelColor: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.view_agenda_outlined),
                            text: 'Current',
                          ),
                          Tab(
                            icon: Icon(Icons.archive_outlined),
                            text: 'Archives',
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  postsAsync.when(
                    loading: () => ListView.builder(
                      itemCount: 4,
                      itemBuilder: (context, index) => const PostCardSkeleton(),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (posts) {
                      final visiblePosts = _visiblePosts(
                        posts,
                        isOwnProfile: isOwnProfile,
                        isFollowingProfileOwner: isFollowingProfileOwner,
                      );

                      if (visiblePosts.isEmpty) {
                        return const Center(child: Text('No posts yet'));
                      }

                      return ListView.builder(
                        itemCount: visiblePosts.length,
                        padding: const EdgeInsets.only(bottom: 88, top: 8),
                        itemBuilder: (context, index) {
                          final post = visiblePosts[index];
                          final isOwnPost = currentUser?.uid == post.userId;
                          return PostCard(
                            post: post,
                            onTap: () => context.push('/post/${post.id}'),
                            onProfileTap: () =>
                                context.push('/profile/${post.userId}'),
                            onMenuTap: isOwnPost
                                ? () {
                                    HapticFeedback.selectionClick();
                                    _showPostOptions(context, post);
                                  }
                                : () => _showReportMenu(context, post.id),
                          );
                        },
                      );
                    },
                  ),
                  archivedPostsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (posts) {
                      final archivedPosts = _visiblePosts(
                        posts,
                        isOwnProfile: isOwnProfile,
                        isFollowingProfileOwner: isFollowingProfileOwner,
                      );
                      if (archivedPosts.isEmpty) {
                        return const Center(
                          child: Text('No archived posts yet'),
                        );
                      }
                      return ListView.builder(
                        itemCount: archivedPosts.length,
                        padding: const EdgeInsets.only(bottom: 88, top: 8),
                        itemBuilder: (context, index) {
                          final post = archivedPosts[index];
                          final isOwnPost = currentUser?.uid == post.userId;
                          return PostCard(
                            post: post,
                            onTap: () => context.push('/post/${post.id}'),
                            onProfileTap: () =>
                                context.push('/profile/${post.userId}'),
                            onMenuTap: isOwnPost
                                ? () {
                                    HapticFeedback.selectionClick();
                                    _showPostOptions(context, post);
                                  }
                                : () => _showReportMenu(context, post.id),
                          );
                        },
                      );
                    },
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

List<PostModel> _visiblePosts(
  List<PostModel> posts, {
  required bool isOwnProfile,
  required bool isFollowingProfileOwner,
}) {
  if (isOwnProfile || isFollowingProfileOwner) {
    return posts;
  }

  return posts.where((post) => post.privacy == PostPrivacy.public).toList();
}

class _FollowButton extends ConsumerStatefulWidget {
  final String currentUserId;
  final String targetUserId;

  const _FollowButton({
    required this.currentUserId,
    required this.targetUserId,
  });

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _isLoading = false;

  Future<void> _handleFollow(bool isCurrentlyFollowing) async {
    if (_isLoading || widget.currentUserId.isEmpty) return;

    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();

    try {
      if (isCurrentlyFollowing) {
        await ref
            .read(userRepositoryProvider)
            .unfollowUser(widget.currentUserId, widget.targetUserId);
      } else {
        await ref
            .read(userRepositoryProvider)
            .followUser(widget.currentUserId, widget.targetUserId);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFollowingAsync = ref.watch(
      isFollowingProvider((
        currentUserId: widget.currentUserId,
        targetUserId: widget.targetUserId,
      )),
    );

    final isFollowing = isFollowingAsync.valueOrNull ?? false;

    return FilledButton.tonalIcon(
      onPressed: _isLoading ? null : () => _handleFollow(isFollowing),
      icon: Icon(
        isFollowing ? Icons.person_remove_outlined : Icons.person_add_alt_1,
      ),
      label: Text(
        _isLoading ? 'Please wait...' : (isFollowing ? 'Following' : 'Follow'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return false;
  }
}
