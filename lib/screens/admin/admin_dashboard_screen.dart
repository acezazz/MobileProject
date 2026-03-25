import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  static final _db = FirebaseFirestore.instance;

  static final Stream<int> _usersCountStream = _db
      .collection('users')
      .snapshots()
      .map((snapshot) => snapshot.size);

  static final Stream<int> _postsCountStream = _db
      .collection('posts')
      .snapshots()
      .map((snapshot) => snapshot.size);

  static final Stream<int> _pendingReportsCountStream = _db
      .collection('reports')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) => snapshot.size);

  static final Stream<int> _suspendedUsersCountStream = _db
      .collection('users')
      .where('isSuspended', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.size);

  static final Stream<int> _archivedPostsCountStream = _db
      .collection('posts')
      .where('status', isEqualTo: 'archived')
      .snapshots()
      .map((snapshot) => snapshot.size);

  static final Stream<int> _adminNotificationsCountStream = _db
      .collection('admin_notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.size);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Monitoring',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text('Track users, posts, reports, and moderation health.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatCard(
                title: 'Users',
                icon: Icons.group_outlined,
                stream: _usersCountStream,
              ),
              _StatCard(
                title: 'Posts',
                icon: Icons.feed_outlined,
                stream: _postsCountStream,
              ),
              _StatCard(
                title: 'Pending Reports',
                icon: Icons.report_gmailerrorred,
                stream: _pendingReportsCountStream,
              ),
              _StatCard(
                title: 'Suspended',
                icon: Icons.gpp_bad_outlined,
                stream: _suspendedUsersCountStream,
              ),
              _StatCard(
                title: 'Archived Posts',
                icon: Icons.archive_outlined,
                stream: _archivedPostsCountStream,
              ),
              _StatCard(
                title: 'Admin Alerts',
                icon: Icons.notifications_active_outlined,
                stream: _adminNotificationsCountStream,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AdminTile(
            icon: Icons.report_gmailerrorred,
            title: 'Reports Queue',
            subtitle: 'Review user and content reports',
            onTap: () => context.push('/admin/reports'),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.manage_accounts,
            title: 'Manage Users',
            subtitle: 'Suspend users and manage accounts',
            onTap: () => context.push('/admin/users'),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.monitor,
            title: 'Posts Monitoring',
            subtitle: 'Monitor and inspect all published posts',
            onTap: () => context.push('/admin/posts'),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.archive_outlined,
            title: 'Archives Monitoring',
            subtitle: 'Browse archived posts and open details',
            onTap: () => context.push('/admin/archives'),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.notifications_outlined,
            title: 'Admin Notifications',
            subtitle: 'Warnings, suspensions, and moderation events',
            onTap: () => context.push('/admin/notifications'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Stream<int> stream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) {
              final count = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count?.toString() ?? '...',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
