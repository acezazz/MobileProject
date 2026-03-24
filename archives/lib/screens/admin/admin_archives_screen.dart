import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminArchivesScreen extends StatelessWidget {
  const AdminArchivesScreen({super.key});

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final Stream<QuerySnapshot<Map<String, dynamic>>>
  _archivedPostsStream = _db
      .collection('posts')
      .where('status', isEqualTo: 'archived')
      .limit(200)
      .snapshots();

  Future<void> _restorePost({
    required BuildContext context,
    required String postId,
  }) async {
    try {
      await _db.collection('posts').doc(postId).update({'status': 'published'});
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post restored.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to restore post: $e')));
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
      appBar: AppBar(title: const Text('Archives Monitoring')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _archivedPostsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed: ${snapshot.error}'));
          }

          final docs = [...(snapshot.data?.docs ?? const [])]
            ..sort((a, b) {
              final aTs = a.data()['createdAt'];
              final bTs = b.data()['createdAt'];
              final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(1970);
              final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(1970);
              return bDate.compareTo(aDate);
            });
          if (docs.isEmpty) {
            return const Center(child: Text('No archived posts found.'));
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
              final createdAt = data['createdAt'];
              final createdLabel = createdAt is Timestamp
                  ? createdAt.toDate().toLocal().toString()
                  : 'Unknown time';

              return Card(
                child: ListTile(
                  title: Text('@$author'),
                  subtitle: Text(
                    '${content.isEmpty ? '(no text)' : content}\n$createdLabel',
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
                        tooltip: 'Archive actions',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'restore') {
                            final confirmed = await _confirmAction(
                              context,
                              title: 'Restore post?',
                              message:
                                  'This post will be moved back to published posts.',
                              confirmLabel: 'Restore',
                            );
                            if (!confirmed) return;
                            await _restorePost(
                              context: context,
                              postId: postId,
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
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'restore',
                            child: Text('Restore post'),
                          ),
                          PopupMenuItem(
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
