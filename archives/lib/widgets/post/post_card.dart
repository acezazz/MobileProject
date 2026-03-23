import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/theme/app_colors.dart';
import '../../core/navigation/interaction_gate.dart';
import '../../models/interaction_intent.dart';
import '../../models/post_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/user_providers.dart';
import '../common/avatar_widget.dart';

class PostCard extends ConsumerWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onRepostTap;
  final VoidCallback? onShareTap;
  final String? currentUserIdOverride;
  final bool hideCommentAction;
  final bool preferUsernameInHeader;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onProfileTap,
    this.onMenuTap,
    this.onCommentTap,
    this.onRepostTap,
    this.onShareTap,
    this.currentUserIdOverride,
    this.hideCommentAction = false,
    this.preferUsernameInHeader = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final uid = currentUserIdOverride ?? currentUser?.uid ?? '';
    final livePost = ref.watch(postStreamProvider(post.id)).valueOrNull ?? post;
    final authorAsync = ref.watch(userProfileProvider(livePost.userId));
    final liveAuthor = authorAsync.valueOrNull;

    final authorPhoto = (liveAuthor?.profilePhoto ?? '').trim().isNotEmpty
        ? liveAuthor!.profilePhoto
        : livePost.userProfilePhoto;
    final authorName = (liveAuthor?.name ?? '').trim().isNotEmpty
        ? liveAuthor!.name
        : (livePost.userName.trim().isNotEmpty ? livePost.userName : 'User');
    final authorUsername = (liveAuthor?.username ?? '').trim().isNotEmpty
        ? liveAuthor!.username
        : livePost.userUsername;
    final mediaUrls = livePost.allImageUrls;
    final privacyIcon = livePost.privacy == PostPrivacy.public
        ? Icons.public
        : Icons.group_outlined;
    final privacyLabel = livePost.privacy == PostPrivacy.public
        ? 'Public post'
        : 'Followers only';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: onProfileTap,
                    child: AvatarWidget(
                      imageUrl: authorPhoto,
                      name: authorName,
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onProfileTap,
                      child: preferUsernameInHeader
                          ? Text(
                              '@$authorUsername',
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    authorName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '@$authorUsername',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Text(
                    timeago.format(livePost.createdAt, locale: 'en_short'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: privacyLabel,
                    child: Icon(
                      privacyIcon,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (onMenuTap != null)
                    IconButton(
                      onPressed: onMenuTap,
                      splashRadius: 18,
                      icon: const Icon(Icons.more_horiz, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _LikeableContent(post: livePost, onTap: onTap),
              if (mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                Hero(
                  tag: 'post-image-${livePost.id}',
                  child: _PostMediaGallery(
                    postId: livePost.id,
                    imageUrls: mediaUrls,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _ActionRow(
                post: livePost,
                currentUserId: uid,
                onCommentTap: onCommentTap,
                onRepostTap: onRepostTap,
                onShareTap: onShareTap,
                hideCommentAction: hideCommentAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMediaGallery extends StatefulWidget {
  final String postId;
  final List<String> imageUrls;

  const _PostMediaGallery({required this.postId, required this.imageUrls});

  @override
  State<_PostMediaGallery> createState() => _PostMediaGalleryState();
}

class _PostMediaGalleryState extends State<_PostMediaGallery> {
  late final PageController _pageController;
  int _currentIndex = 0;

  void _goToPage(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (value) {
                setState(() => _currentIndex = value);
              },
              itemBuilder: (context, index) {
                final imageUrl = widget.imageUrls[index];
                return CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                );
              },
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              left: 8,
              child: IconButton.filled(
                onPressed: _currentIndex > 0
                    ? () => _goToPage(_currentIndex - 1)
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                  disabledBackgroundColor: Colors.black26,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                ),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous photo',
              ),
            ),
          if (widget.imageUrls.length > 1)
            Positioned(
              right: 8,
              child: IconButton.filled(
                onPressed: _currentIndex < widget.imageUrls.length - 1
                    ? () => _goToPage(_currentIndex + 1)
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                  disabledBackgroundColor: Colors.black26,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                ),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next photo',
              ),
            ),
          if (widget.imageUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${widget.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LikeableContent extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const _LikeableContent({required this.post, required this.onTap});

  @override
  ConsumerState<_LikeableContent> createState() => _LikeableContentState();
}

class _LikeableContentState extends ConsumerState<_LikeableContent> {
  bool _heartVisible = false;

  Future<void> _doubleTapLike() async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) return;

    final isLiked = await ref
        .read(postRepositoryProvider)
        .hasUserLikedPost(widget.post.id, currentUser.uid);
    if (!isLiked) {
      await ref
          .read(postRepositoryProvider)
          .likePost(widget.post.id, currentUser.uid);
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() => _heartVisible = true);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() => _heartVisible = false);
      }
    }

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _doubleTapLike,
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.post.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          AnimatedOpacity(
            opacity: _heartVisible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(
              Icons.favorite,
              color: AppColors.likeRed,
              size: 74,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerStatefulWidget {
  final PostModel post;
  final String currentUserId;
  final VoidCallback? onCommentTap;
  final VoidCallback? onRepostTap;
  final VoidCallback? onShareTap;
  final bool hideCommentAction;

  const _ActionRow({
    required this.post,
    required this.currentUserId,
    this.onCommentTap,
    this.onRepostTap,
    this.onShareTap,
    this.hideCommentAction = false,
  });

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow> {
  bool _isLikeBusy = false;
  bool? _optimisticLiked;

  Future<bool> _ensureAuth(InteractionAction action) {
    return ensureAuthenticatedForIntent(
      context: context,
      ref: ref,
      intent: InteractionIntent(
        targetType: InteractionTargetType.post,
        targetId: widget.post.id,
        action: action,
      ),
    );
  }

  Future<void> _toggleLike(bool currentIsLiked) async {
    if (_isLikeBusy) return;

    final nextLiked = !currentIsLiked;
    setState(() {
      _isLikeBusy = true;
      _optimisticLiked = nextLiked;
    });

    HapticFeedback.selectionClick();

    try {
      final repo = ref.read(postRepositoryProvider);
      if (nextLiked) {
        await repo.likePost(widget.post.id, widget.currentUserId);
      } else {
        await repo.unlikePost(widget.post.id, widget.currentUserId);
      }
      if (mounted) {
        setState(() {
          _isLikeBusy = false;
          _optimisticLiked = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLikeBusy = false;
          _optimisticLiked = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update like. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final likeStatus = widget.currentUserId.isEmpty
        ? const AsyncData(false)
        : ref.watch(
            likeStatusProvider((
              postId: widget.post.id,
              userId: widget.currentUserId,
            )),
          );

    final liveLikesCount =
        ref.watch(postLikesCountProvider(widget.post.id)).valueOrNull ??
        widget.post.likesCount;
    final liveCommentsCount =
        ref.watch(postCommentsCountProvider(widget.post.id)).valueOrNull ??
        widget.post.commentsCount;

    final streamLiked = likeStatus.valueOrNull ?? false;
    final isLiked = _optimisticLiked ?? streamLiked;
    final likeCount =
        liveLikesCount +
        (_optimisticLiked == null
            ? 0
            : ((_optimisticLiked! == streamLiked)
                  ? 0
                  : (_optimisticLiked! ? 1 : -1)));
    final displayLikeCount = likeCount < 0 ? 0 : likeCount;

    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return Row(
      children: [
        IconButton(
          onPressed: _isLikeBusy
              ? null
              : () async {
                  if (widget.currentUserId.isEmpty) {
                    await _ensureAuth(InteractionAction.like);
                    return;
                  }
                  await _toggleLike(isLiked);
                },
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked
                ? AppColors.likeRed
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (displayLikeCount > 0) Text('$displayLikeCount', style: labelStyle),
        const SizedBox(width: 8),
        if (!widget.hideCommentAction)
          IconButton(
            onPressed: () async {
              if (widget.currentUserId.isEmpty) {
                final allowed = await _ensureAuth(InteractionAction.comment);
                if (!allowed) return;
              }
              widget.onCommentTap?.call();
            },
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.mode_comment_outlined),
          ),
        if (liveCommentsCount > 0)
          Text('$liveCommentsCount', style: labelStyle),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            if (widget.currentUserId.isEmpty) {
              final allowed = await _ensureAuth(InteractionAction.repost);
              if (!allowed) return;
            }
            HapticFeedback.selectionClick();
            widget.onRepostTap?.call();
          },
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.repeat),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            if (widget.currentUserId.isEmpty) {
              final allowed = await _ensureAuth(InteractionAction.share);
              if (!allowed) return;
            }
            widget.onShareTap?.call();
          },
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.send_outlined),
        ),
      ],
    );
  }
}
