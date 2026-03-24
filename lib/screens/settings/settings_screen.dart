import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/role_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final showAdmin = isAdminOrHigher(role);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: scheme.surfaceContainerLow,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings_suggest_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Controls',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage profile, access, and session preferences.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _SectionHeader(title: 'Account'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.textSecondary,
                ),
                title: const Text(
                  'Edit Profile',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textHint,
                ),
                onTap: () => context.push('/edit-profile'),
              ),
            ],
          ),

          const SizedBox(height: 4),
          const _SectionHeader(title: 'About'),
          const _SettingsCard(
            children: [
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  'App Version',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                trailing: Text(
                  '1.0.0',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ),
            ],
          ),

          if (showAdmin) ...[
            const SizedBox(height: 4),
            const _SectionHeader(title: 'Administration'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text(
                    'Admin Panel',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: const Text('Monitoring, reports, and moderation'),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textHint,
                  ),
                  onTap: () => context.push('/admin'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 4),
          const _SectionHeader(title: 'Session'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text(
                  'Log Out',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Log Out',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).logout();
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.accentBeigeMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
