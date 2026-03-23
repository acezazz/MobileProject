import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/web_image_picker.dart';
import '../../providers/auth_providers.dart';
import '../../providers/user_providers.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isPrivate = false;
  bool _isLoading = false;
  bool _initialized = false;

  Uint8List? _selectedImageBytes;
  String? _currentPhotoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final (bytes, _) = await pickImageFromBrowser();
      if (bytes != null) {
        setState(() => _selectedImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;

      String? photoUrl = _currentPhotoUrl;

      // Upload new photo if selected
      if (_selectedImageBytes != null) {
        photoUrl = await CloudinaryService.uploadImage(
          imageBytes: _selectedImageBytes!,
          fileName: 'profile_$uid.jpg',
          folder: 'archives/profiles',
        );
      }

      await ref.read(userRepositoryProvider).updateProfile(uid, {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profilePhoto': photoUrl ?? '',
        'isPrivate': _isPrivate,
      });

      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }

          if (!_initialized) {
            _nameController.text = user.name;
            _bioController.text = user.bio;
            _currentPhotoUrl = user.profilePhoto;
            _isPrivate = user.isPrivate;
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Avatar with upload
                  GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: Stack(
                      children: [
                        if (_selectedImageBytes != null)
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: MemoryImage(_selectedImageBytes!),
                          )
                        else
                          AvatarWidget(
                            imageUrl: user.profilePhoto,
                            name: user.name,
                            radius: 48,
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to change photo',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    controller: _nameController,
                    hintText: 'Full Name',
                    fillColor: AppColors.accentBeige,
                    textColor: AppColors.inkDark,
                    hintColor: AppColors.inkDark,
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: AppColors.inkDark,
                    ),
                    validator: Validators.name,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _bioController,
                    hintText: 'Bio',
                    maxLines: 3,
                    fillColor: AppColors.accentBeige,
                    textColor: AppColors.inkDark,
                    hintColor: AppColors.inkDark,
                    prefixIcon: const Icon(
                      Icons.info_outline,
                      color: AppColors.inkDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_bioController.text.length} / ${AppConstants.maxBioLength}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Private toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Private Account',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: const Text(
                        'Only followers can see your posts',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                      ),
                      value: _isPrivate,
                      onChanged: (val) => setState(() => _isPrivate = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: _isLoading ? 'Saving...' : 'Save',
                    isLoading: _isLoading,
                    onPressed: _handleSave,
                    backgroundColor: AppColors.accentBeigeMuted,
                    foregroundColor: AppColors.inkDark,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
