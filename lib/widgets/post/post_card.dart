import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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
  final VoidCallback? onSendTap;
  final String? currentUserIdOverride;
  final bool hideLikeAction;
  final bool hideCommentAction;
  final bool preferUsernameInHeader;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onProfileTap,
    this.onMenuTap,
    this.onCommentTap,
    this.onSendTap,
    this.currentUserIdOverride,
    this.hideLikeAction = false,
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
    final imageUrls = livePost.allImageUrls;
    final videoUrls = livePost.videoUrls;
    final fileUrls = livePost.fileUrls;
    final tags = livePost.tags;
    final (
      IconData privacyIcon,
      String privacyLabel,
    ) = switch (livePost.privacy) {
      PostPrivacy.public => (Icons.public, 'Public post'),
      PostPrivacy.followersOnly => (Icons.group_outlined, 'Followers only'),
      PostPrivacy.onlyMe => (Icons.lock_outline, 'Only me'),
    };

    Future<void> handleProfileTap() async {
      if (onProfileTap == null) return;

      if (uid.isEmpty) {
        final canOpen = await ensureAuthenticatedForPath(
          context: context,
          ref: ref,
          destinationPath: '/profile/${livePost.userId}',
        );
        if (!canOpen) return;
      }

      onProfileTap?.call();
    }

    return Semantics(
      label: 'Post by $authorName',
      button: onTap != null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: handleProfileTap,
                        child: AvatarWidget(
                          imageUrl: authorPhoto,
                          name: authorName,
                          radius: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: handleProfileTap,
                          child: preferUsernameInHeader
                              ? Text(
                                  authorUsername,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
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
                                        authorUsername,
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
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
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.more_horiz, size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LikeableContent(
                    post: livePost,
                    onTap: onTap,
                    disableDoubleTapLike: hideLikeAction,
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                              child: Text(
                                '#$tag',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Hero(
                      tag: 'post-image-${livePost.id}',
                      child: _PostMediaGallery(
                        postId: livePost.id,
                        imageUrls: imageUrls,
                      ),
                    ),
                  ],
                  if (videoUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PostVideoAttachments(videoUrls: videoUrls),
                  ],
                  if (fileUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PostFileAttachments(fileUrls: fileUrls),
                  ],
                  const SizedBox(height: 10),
                  _ActionRow(
                    post: livePost,
                    currentUserId: uid,
                    onCommentTap: onCommentTap,
                    onSendTap: onSendTap,
                    hideLikeAction: hideLikeAction,
                    hideCommentAction: hideCommentAction,
                  ),
                ],
              ),
            ),
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

class _PostVideoAttachments extends StatelessWidget {
  final List<String> videoUrls;

  const _PostVideoAttachments({required this.videoUrls});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: videoUrls
          .map(
            (url) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              child: _InlineVideoPlayer(videoUrl: url),
            ),
          )
          .toList(),
    );
  }
}

class _PostFileAttachments extends StatelessWidget {
  final List<String> fileUrls;

  const _PostFileAttachments({required this.fileUrls});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: fileUrls.map((url) => _FilePreviewTile(fileUrl: url)).toList(),
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _InlineVideoPlayer({required this.videoUrl});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri != null) {
      _controller = VideoPlayerController.networkUrl(uri)
        ..initialize()
            .then((_) {
              if (mounted) {
                setState(() {});
              }
            })
            .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final isPlaying = controller.value.isPlaying;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio == 0
                ? 16 / 9
                : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
                setState(() {});
              },
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              ),
            ),
            Expanded(
              child: Text(
                _displayNameFromUrl(widget.videoUrl),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilePreviewTile extends StatelessWidget {
  final String fileUrl;

  const _FilePreviewTile({required this.fileUrl});

  Future<void> _openFilePreview(BuildContext context) async {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file preview.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.file(), color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _displayNameFromUrl(fileUrl),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => _openFilePreview(context),
            child: const Text('Preview'),
          ),
        ],
      ),
    );
  }
}

String _displayNameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (uri.pathSegments.isEmpty) return url;
  return uri.pathSegments.last;
}

class _LikeableContent extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final bool disableDoubleTapLike;

  const _LikeableContent({
    required this.post,
    required this.onTap,
    this.disableDoubleTapLike = false,
  });

  @override
  ConsumerState<_LikeableContent> createState() => _LikeableContentState();
}

class _LikeableContentState extends ConsumerState<_LikeableContent> {
  bool _heartVisible = false;

  Future<void> _doubleTapLike() async {
    if (widget.disableDoubleTapLike) return;

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
      onDoubleTap: widget.disableDoubleTapLike ? null : _doubleTapLike,
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
            child: Icon(
              PhosphorIcons.heart(PhosphorIconsStyle.fill),
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
  final VoidCallback? onSendTap;
  final bool hideLikeAction;
  final bool hideCommentAction;

  const _ActionRow({
    required this.post,
    required this.currentUserId,
    this.onCommentTap,
    this.onSendTap,
    this.hideLikeAction = false,
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
    if (widget.hideLikeAction && widget.hideCommentAction) {
      return const SizedBox.shrink();
    }

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

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (!widget.hideLikeAction) ...[
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
              tooltip: isLiked ? 'Unlike post' : 'Like post',
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: isLiked
                    ? AppColors.likeRed
                    : AppColors.textSecondary,
              ),
              icon: Icon(
                isLiked
                    ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                    : PhosphorIcons.heart(),
                size: 26,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              displayLikeCount > 0 ? '$displayLikeCount' : '',
              style: labelStyle?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(width: 24),
          ],
          if (!widget.hideCommentAction) ...[
            IconButton(
              onPressed: () async {
                if (widget.currentUserId.isEmpty) {
                  final allowed = await _ensureAuth(InteractionAction.comment);
                  if (!allowed) return;
                }
                widget.onCommentTap?.call();
              },
              tooltip: 'Open comments',
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.textSecondary,
              ),
              icon: Icon(PhosphorIcons.chatCircle(), size: 26),
            ),
            const SizedBox(width: 4),
            Text(
              liveCommentsCount > 0 ? '$liveCommentsCount' : '',
              style: labelStyle?.copyWith(color: AppColors.textSecondary),
            ),
            if (widget.onSendTap != null) ...[
              const SizedBox(width: 24),
              IconButton(
                onPressed: widget.onSendTap,
                tooltip: 'Send to followed users',
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.textSecondary,
                ),
                icon: Icon(PhosphorIcons.paperPlaneTilt(), size: 25),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
