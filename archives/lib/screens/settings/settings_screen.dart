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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          // Account Section
          const _SectionHeader(title: 'Account'),
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
          const Divider(color: AppColors.divider),

          // About Section
          const _SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: AppColors.textSecondary),
            title: Text(
              'App Version',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: Text(
              '1.0.0',
              style: TextStyle(color: AppColors.textHint),
            ),
          ),
          const Divider(color: AppColors.divider),

          if (showAdmin) ...[
            const _SectionHeader(title: 'Administration'),
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppColors.textSecondary,
              ),
              title: const Text(
                'Admin Panel',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
              ),
              onTap: () => context.push('/admin'),
            ),
            const Divider(color: AppColors.divider),
          ],

          // Danger Zone
          const _SectionHeader(title: 'Session'),
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
