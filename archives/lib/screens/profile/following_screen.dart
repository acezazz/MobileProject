import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/user_providers.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/branded_state_view.dart';

class FollowingScreen extends ConsumerWidget {
  final String userId;
  const FollowingScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingListProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: followingAsync.when(
        data: (following) {
          if (following.isEmpty) {
            return const BrandedStateView(
              icon: Icons.person_search_outlined,
              title: 'Not following anyone',
              subtitle: 'Follow people to see them listed here.',
            );
          }
          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              final follow = following[index];
              final uid = follow.followingId;
              final profileAsync = ref.watch(userProfileProvider(uid));

              return profileAsync.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: AvatarWidget(
                        imageUrl: user.profilePhoto,
                        name: user.name,
                        radius: 22,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '@${user.username}',
                        style: const TextStyle(color: AppColors.textHint),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                      onTap: () => context.push('/profile/$uid'),
                    ),
                  );
                },
                loading: () => const ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                  title: Text(
                    'Loading...',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                ),
                error: (_, _) => const SizedBox.shrink(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BrandedStateView(
          icon: Icons.error_outline,
          title: 'Could not load following',
          subtitle: '$e',
        ),
      ),
    );
  }
}
