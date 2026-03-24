import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminPostsScreen extends StatelessWidget {
  const AdminPostsScreen({super.key});

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream = _db
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();

  Future<void> _updatePostStatus({
    required BuildContext context,
    required String postId,
    required String status,
  }) async {
    try {
      await _db.collection('posts').doc(postId).update({'status': status});
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Post marked as $status.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update post: $e')));
    }
  }

  Future<void> _deletePost({
    required BuildContext context,
    required String postId,
  }) async {
    try {
      await _db.collection('posts').doc(postId).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post deleted.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
    }
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Posts Monitoring')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final postId = docs[index].id;
              final author =
                  (data['userUsername'] ?? data['userName'] ?? 'user')
                      .toString();
              final content = (data['content'] ?? '').toString().trim();
              final status = (data['status'] ?? 'unknown').toString();
              final privacy = (data['privacy'] ?? 'public').toString();
              final createdAt = data['createdAt'];
              final isArchived = status == 'archived';
              final createdLabel = createdAt is Timestamp
                  ? createdAt.toDate().toLocal().toString()
                  : 'Unknown time';

              return Card(
                child: ListTile(
                  title: Text('@$author'),
                  subtitle: Text(
                    '${content.isEmpty ? '(no text)' : content}\n'
                    'status: $status • privacy: $privacy\n'
                    '$createdLabel',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Open post',
                        onPressed: () => context.push('/post/$postId'),
                        icon: const Icon(Icons.open_in_new),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Post actions',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'archive') {
                            final confirmed = await _confirmAction(
                              context,
                              title: 'Archive post?',
                              message:
                                  'This post will move to Archives Monitoring.',
                              confirmLabel: 'Archive',
                            );
                            if (!confirmed) return;
                            await _updatePostStatus(
                              context: context,
                              postId: postId,
                              status: 'archived',
                            );
                            return;
                          }

                          if (value == 'restore') {
                            final confirmed = await _confirmAction(
                              context,
                              title: 'Restore post?',
                              message:
                                  'This post will be restored as published.',
                              confirmLabel: 'Restore',
                            );
                            if (!confirmed) return;
                            await _updatePostStatus(
                              context: context,
                              postId: postId,
                              status: 'published',
                            );
                            return;
                          }

                          if (value == 'delete') {
                            final confirmed = await _confirmAction(
                              context,
                              title: 'Delete post permanently?',
                              message: 'This action cannot be undone.',
                              confirmLabel: 'Delete',
                            );
                            if (!confirmed) return;
                            await _deletePost(context: context, postId: postId);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: isArchived ? 'restore' : 'archive',
                            child: Text(
                              isArchived ? 'Restore post' : 'Archive post',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete post'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => context.push('/post/$postId'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
