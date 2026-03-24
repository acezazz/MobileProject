import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/web_image_picker.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/user_providers.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/chat/emoji_reaction_picker.dart';
import '../../widgets/common/avatar_widget.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? repostId;

  const CreatePostScreen({super.key, this.repostId});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();

  PostPrivacy _privacy = PostPrivacy.public;
  final List<({Uint8List bytes, String name})> _selectedImages = [];
  final List<_PickedVideo> _selectedVideos = [];
  final List<({Uint8List bytes, String name})> _selectedFiles = [];
  final List<String> _tags = [];
  bool _isUploading = false;

  bool get _hasAttachments =>
      _selectedImages.isNotEmpty ||
      _selectedVideos.isNotEmpty ||
      _selectedFiles.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final repostId = widget.repostId;
    if (repostId != null && repostId.isNotEmpty) {
      _contentController.text = 'Repost: /post/$repostId\n\n';
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  String _privacyLabel(PostPrivacy privacy) {
    switch (privacy) {
      case PostPrivacy.public:
        return 'Public';
      case PostPrivacy.followersOnly:
        return 'Followers only';
      case PostPrivacy.onlyMe:
        return 'Only me';
    }
  }

  Future<void> _pickImages() async {
    try {
      final picked = await pickImagesFromBrowser();
      if (picked.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _selectedImages.addAll(picked));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not pick images: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final (bytes, name, path) = await pickVideoFromBrowser();
      if (bytes == null || name == null || path == null) return;
      final lowerName = name.toLowerCase();
      if (!lowerName.endsWith('.mp4')) {
        if (!mounted) return;
        AppSnackBar.error(context, 'Only mp4 videos are supported.');
        return;
      }
      HapticFeedback.selectionClick();
      setState(
        () => _selectedVideos.add(
          _PickedVideo(bytes: bytes, name: name, previewPath: path),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not pick video: $e');
    }
  }

  Future<void> _pickGifs() async {
    try {
      final picked = await pickGifsFromBrowser();
      if (picked.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _selectedImages.addAll(picked));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not pick gif: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final picked = await pickFilesFromBrowser();
      if (picked.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _selectedFiles.addAll(picked));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not pick files: $e');
    }
  }

  void _insertEmojiToComposer(String emoji) {
    final value = _contentController.value;
    final text = value.text;
    final selection = value.selection;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    setState(() {});
  }

  Future<void> _openPostEmojiPicker() async {
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

  Future<List<UserModel>> _loadTaggableUsers() async {
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

      // Allowed tagging rule:
      // - Followers can be tagged
      // - Following users can be tagged only if their account is public
      final canTag = followerIds.contains(uid) || !user.isPrivate;
      if (canTag) {
        users.add(user);
      }
    }

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Future<void> _openTaggableUsersSheet() async {
    final users = await _loadTaggableUsers();
    if (!mounted) return;

    if (users.isEmpty) {
      AppSnackBar.error(context, 'No users available to tag right now.');
      return;
    }

    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) =>
          _TaggableUsersSheet(users: users, initialTags: _tags),
    );

    if (picked == null) return;
    setState(() {
      _tags
        ..clear()
        ..addAll(picked);
    });
  }

  Future<List<String>> _uploadMediaBatch({
    required List<({Uint8List bytes, String name})> localItems,
    required Future<String?> Function(Uint8List bytes, String name) uploader,
  }) async {
    final urls = <String>[];
    for (final item in localItems) {
      final url = await uploader(item.bytes, item.name);
      if (url != null && url.trim().isNotEmpty) {
        urls.add(url.trim());
      }
    }
    return urls;
  }

  Future<void> _handlePost() async {
    final content = _contentController.text.trim();
    if ((content.isEmpty && !_hasAttachments) || _isUploading) return;

    setState(() => _isUploading = true);

    try {
      final imageUrls = await _uploadMediaBatch(
        localItems: _selectedImages,
        uploader: (bytes, name) => CloudinaryService.uploadImage(
          imageBytes: bytes,
          fileName: name,
          folder: 'archives/posts/images',
        ),
      );

      final videoUrls = await _uploadMediaBatch(
        localItems: _selectedVideos
            .map((video) => (bytes: video.bytes, name: video.name))
            .toList(),
        uploader: (bytes, name) => CloudinaryService.uploadVideo(
          videoBytes: bytes,
          fileName: name,
          folder: 'archives/posts/videos',
        ),
      );

      final fileUrls = await _uploadMediaBatch(
        localItems: _selectedFiles,
        uploader: (bytes, name) => CloudinaryService.uploadRawFile(
          fileBytes: bytes,
          fileName: name,
          folder: 'archives/posts/files',
        ),
      );

      final success = await ref
          .read(createPostProvider.notifier)
          .createPost(
            content: content,
            imageUrls: imageUrls.isEmpty ? null : imageUrls,
            videoUrls: videoUrls.isEmpty ? null : videoUrls,
            fileUrls: fileUrls.isEmpty ? null : fileUrls,
            tags: _tags,
            privacy: _privacy,
          );

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (success) {
        HapticFeedback.mediumImpact();
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      AppSnackBar.error(context, 'Upload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name
        : 'You';
    final isLoading = _isUploading;
    final canPost =
        (_contentController.text.trim().isNotEmpty || _hasAttachments) &&
        !isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Archive'),
        actions: [
          TextButton(
            onPressed: canPost ? _handlePost : null,
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: profile?.profilePhoto,
                  name: displayName,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<PostPrivacy>(
                          value: _privacy,
                          borderRadius: BorderRadius.circular(12),
                          isDense: true,
                          items: PostPrivacy.values
                              .map(
                                (privacy) => DropdownMenuItem(
                                  value: privacy,
                                  child: Text(_privacyLabel(privacy)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _privacy = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Add emoji',
                      visualDensity: VisualDensity.compact,
                      onPressed: isLoading ? null : _openPostEmojiPicker,
                      icon: const Icon(Icons.emoji_emotions_outlined),
                    ),
                    IconButton(
                      tooltip: 'Tag users',
                      visualDensity: VisualDensity.compact,
                      onPressed: isLoading ? null : _openTaggableUsersSheet,
                      icon: const Icon(Icons.alternate_email_rounded),
                    ),
                    const Spacer(),
                    Text(
                      '${_contentController.text.length}/${AppConstants.maxPostLength}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  maxLength: AppConstants.maxPostLength,
                  maxLines: null,
                  minLines: 8,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Write your archive update... add context, mood, and story.',
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map(
                          (tag) => InputChip(
                            label: Text('@$tag'),
                            onDeleted: () {
                              setState(() => _tags.remove(tag));
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attachments',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (_hasAttachments)
                  SizedBox(
                    height: 130,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._selectedImages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _LocalAttachmentTile(
                            label: 'Image',
                            detail: item.name,
                            icon: Icons.image_outlined,
                            thumbBytes: item.bytes,
                            onRemove: () {
                              setState(() => _selectedImages.removeAt(index));
                            },
                          );
                        }),
                        ..._selectedVideos.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _LocalVideoAttachmentTile(
                            label: 'Video',
                            detail: item.name,
                            previewPath: item.previewPath,
                            onRemove: () {
                              setState(() => _selectedVideos.removeAt(index));
                            },
                          );
                        }),
                        ..._selectedFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _LocalAttachmentTile(
                            label: 'File',
                            detail: item.name,
                            icon: Icons.insert_drive_file_outlined,
                            onRemove: () {
                              setState(() => _selectedFiles.removeAt(index));
                            },
                          );
                        }),
                        _LocalAttachmentAddTile(
                          icon: Icons.add_photo_alternate_outlined,
                          label: 'Add image',
                          onTap: _pickImages,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'No attachments yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ComposerActionButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Image',
                      onTap: isLoading ? null : _pickImages,
                    ),
                    _ComposerActionButton(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      onTap: isLoading ? null : _pickVideo,
                    ),
                    _ComposerActionButton(
                      icon: Icons.gif_box_outlined,
                      label: 'GIF',
                      onTap: isLoading ? null : _pickGifs,
                    ),
                    _ComposerActionButton(
                      icon: Icons.attach_file,
                      label: 'File',
                      onTap: isLoading ? null : _pickFiles,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaggableUsersSheet extends StatefulWidget {
  final List<UserModel> users;
  final List<String> initialTags;

  const _TaggableUsersSheet({required this.users, required this.initialTags});

  @override
  State<_TaggableUsersSheet> createState() => _TaggableUsersSheetState();
}

class _TaggableUsersSheetState extends State<_TaggableUsersSheet> {
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

class _ComposerActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ComposerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _LocalAttachmentTile extends StatelessWidget {
  final String label;
  final String detail;
  final IconData icon;
  final Uint8List? thumbBytes;
  final VoidCallback onRemove;

  const _LocalAttachmentTile({
    required this.label,
    required this.detail,
    required this.icon,
    required this.onRemove,
    this.thumbBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumbBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      thumbBytes!,
                      height: 60,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 60,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              onPressed: onRemove,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalVideoAttachmentTile extends StatefulWidget {
  final String label;
  final String detail;
  final String previewPath;
  final VoidCallback onRemove;

  const _LocalVideoAttachmentTile({
    required this.label,
    required this.detail,
    required this.previewPath,
    required this.onRemove,
  });

  @override
  State<_LocalVideoAttachmentTile> createState() =>
      _LocalVideoAttachmentTileState();
}

class _LocalVideoAttachmentTileState extends State<_LocalVideoAttachmentTile> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.previewPath);
    if (uri != null) {
      final resolvedUri = uri.hasScheme ? uri : Uri.file(widget.previewPath);
      _controller = VideoPlayerController.networkUrl(resolvedUri)
        ..initialize()
            .then((_) {
              if (mounted) {
                setState(() {});
                _controller?.pause();
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
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 60,
                    width: double.infinity,
                    child:
                        _controller != null && _controller!.value.isInitialized
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              VideoPlayer(_controller!),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: AppColors.surface,
                            alignment: Alignment.center,
                            child: const Icon(Icons.videocam_outlined),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              onPressed: widget.onRemove,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedVideo {
  final Uint8List bytes;
  final String name;
  final String previewPath;

  const _PickedVideo({
    required this.bytes,
    required this.name,
    required this.previewPath,
  });
}

class _LocalAttachmentAddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LocalAttachmentAddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
