import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/user_providers.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/branded_state_view.dart';

class FollowersScreen extends ConsumerWidget {
  final String userId;
  const FollowersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersAsync = ref.watch(followersListProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: followersAsync.when(
        data: (followers) {
          if (followers.isEmpty) {
            return const BrandedStateView(
              icon: Icons.group_outlined,
              title: 'No followers yet',
              subtitle:
                  'When people follow this profile, they will appear here.',
            );
          }
          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final follower = followers[index];
              final uid = follower.followerId;
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
          title: 'Could not load followers',
          subtitle: '$e',
        ),
      ),
    );
  }
}
