import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/comment_model.dart';
import '../../models/post_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/branded_state_view.dart';
import '../../widgets/post/post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final bool focusComments;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.focusComments = false,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentsHeaderKey = GlobalKey();
  bool _isSending = false;
  bool _didApplyInitialFocus = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _focusCommentsSectionIfNeeded() {
    if (!widget.focusComments || _didApplyInitialFocus) return;
    _didApplyInitialFocus = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _commentsHeaderKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    HapticFeedback.selectionClick();

    try {
      final user = await ref.read(currentUserProfileProvider.future);
      if (user == null) return;
      await ref
          .read(postRepositoryProvider)
          .addComment(postId: widget.postId, user: user, content: text);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAdminView = ref.watch(isAdminOrHigherProvider);
    final postAsync = ref.watch(postStreamProvider(widget.postId));
    final commentsAsync = isAdminView
        ? const AsyncData<List<CommentModel>>([])
        : ref.watch(commentsProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (post) {
          if (!isAdminView) {
            _focusCommentsSectionIfNeeded();
          }

          if (post == null) {
            return const BrandedStateView(
              icon: Icons.article_outlined,
              title: 'Post not found',
              subtitle: 'This post may have been deleted.',
            );
          }

          final currentUser = ref.watch(authStateProvider).valueOrNull;
          final currentUserId = currentUser?.uid ?? '';
          final isOwner =
              currentUserId.isNotEmpty && currentUserId == post.userId;
          final isFollowingAuthor = isOwner
              ? true
              : (currentUserId.isEmpty
                    ? false
                    : (ref
                              .watch(
                                isFollowingProvider((
                                  currentUserId: currentUserId,
                                  targetUserId: post.userId,
                                )),
                              )
                              .valueOrNull ??
                          false));
          final canViewPost =
              isAdminView ||
              post.privacy == PostPrivacy.public ||
              isOwner ||
              (post.privacy == PostPrivacy.followersOnly && isFollowingAuthor);

          if (!canViewPost) {
            return const BrandedStateView(
              icon: Icons.lock_outline,
              title: 'Private post',
              subtitle: 'This post is restricted by its privacy setting.',
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    PostCard(
                      post: post,
                      hideLikeAction: isAdminView,
                      hideCommentAction: true,
                    ),
                    if (!isAdminView) ...[
                      Padding(
                        key: _commentsHeaderKey,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Text(
                          'Comments',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      commentsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Error: $e'),
                        ),
                        data: (comments) {
                          if (comments.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: BrandedStateView(
                                icon: Icons.forum_outlined,
                                title: 'No comments yet',
                                subtitle:
                                    'Be the first to start the conversation.',
                              ),
                            );
                          }

                          return Column(
                            children: comments
                                .map(
                                  (comment) => _CommentTile(comment: comment),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (!isAdminView)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Write a comment...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _isSending ? null : _sendComment,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: const Text('Send'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AvatarWidget(
        imageUrl: comment.userProfilePhoto,
        name: comment.userName,
        radius: 18,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              comment.userName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            timeago.format(comment.createdAt, locale: 'en_short'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      subtitle: Text(comment.content),
    );
  }
}
