import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/web_image_picker.dart';
import '../../models/post_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/chat/emoji_reaction_picker.dart';

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
  bool _isUploading = false;

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

  Future<void> _pickImages() async {
    try {
      final picked = await pickImagesFromBrowser();
      if (picked.isNotEmpty) {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedImages.addAll(picked);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
    }
  }

  Future<void> _handlePost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || _isUploading) return;

    setState(() => _isUploading = true);

    final uploadedImageUrls = <String>[];
    if (_selectedImages.isNotEmpty) {
      try {
        for (final image in _selectedImages) {
          final imageUrl = await CloudinaryService.uploadImage(
            imageBytes: image.bytes,
            fileName: image.name,
            folder: 'archives/posts',
          );
          if (imageUrl != null && imageUrl.trim().isNotEmpty) {
            uploadedImageUrls.add(imageUrl.trim());
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
        setState(() => _isUploading = false);
        return;
      }
    }

    final success = await ref
        .read(createPostProvider.notifier)
        .createPost(
          content: content,
          imageUrls: uploadedImageUrls.isEmpty ? null : uploadedImageUrls,
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

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final isLoading = _isUploading;
    final canPost = _contentController.text.trim().isNotEmpty && !isLoading;
    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name
        : 'You';
    final privacyLabel = _privacy == PostPrivacy.public
        ? 'Public'
        : 'Followers';
    final privacyIcon = _privacy == PostPrivacy.public
        ? Icons.public
        : Icons.group_outlined;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    'Create post',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceVariant,
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                children: [
                  Row(
                    children: [
                      AvatarWidget(
                        imageUrl: profile?.profilePhoto,
                        name: displayName,
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            PopupMenuButton<PostPrivacy>(
                              tooltip: 'Post privacy',
                              initialValue: _privacy,
                              onSelected: (value) {
                                setState(() => _privacy = value);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: PostPrivacy.public,
                                  child: Row(
                                    children: [
                                      Icon(Icons.public, size: 18),
                                      SizedBox(width: 8),
                                      Text('Public'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: PostPrivacy.followersOnly,
                                  child: Row(
                                    children: [
                                      Icon(Icons.group_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Followers'),
                                    ],
                                  ),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      privacyIcon,
                                      size: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      privacyLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _contentController,
                    maxLength: AppConstants.maxPostLength,
                    maxLines: null,
                    minLines: 4,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                    buildCounter:
                        (
                          context, {
                          required int currentLength,
                          required bool isFocused,
                          required int? maxLength,
                        }) {
                          return const SizedBox.shrink();
                        },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'What\'s on your mind, $displayName?',
                      hintStyle: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFF950A2),
                              Color(0xFFF5D54A),
                              Color(0xFF6CC4FF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Aa',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.sentiment_satisfied_alt_outlined,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Add emoji',
                        onPressed: _openPostEmojiPicker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedImages.isNotEmpty)
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final image = _selectedImages[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Image.memory(
                                  image.bytes,
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: IconButton.filledTonal(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                    iconSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (_selectedImages.isNotEmpty) const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.surface,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Add to your post',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _PostActionIcon(
                          icon: Icons.photo_library,
                          color: const Color(0xFF30B74A),
                          onTap: isLoading ? null : _pickImages,
                        ),
                        _PostActionIcon(
                          icon: Icons.person_add_alt,
                          color: const Color(0xFF2785F7),
                          onTap: null,
                        ),
                        _PostActionIcon(
                          icon: Icons.sentiment_satisfied_alt,
                          color: const Color(0xFFF7B928),
                          onTap: isLoading ? null : _openPostEmojiPicker,
                        ),
                        _PostActionIcon(
                          icon: Icons.location_on,
                          color: const Color(0xFFFF5D41),
                          onTap: null,
                        ),
                        _PostActionIcon(
                          icon: Icons.gif_box,
                          color: const Color(0xFF2BC6B2),
                          onTap: null,
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.more_horiz,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canPost ? _handlePost : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.divider,
                    disabledBackgroundColor: AppColors.divider,
                    foregroundColor: AppColors.textSecondary,
                    disabledForegroundColor: AppColors.textSecondary,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _PostActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: color, size: 22),
      tooltip: onTap == null ? 'Coming soon' : null,
    );
  }
}
