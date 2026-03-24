import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';

class MyArchivedPostsScreen extends ConsumerWidget {
  const MyArchivedPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final userId = currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Archived Posts')),
        body: const Center(child: Text('Please login to view archived posts.')),
      );
    }

    final archivedPostsAsync = ref.watch(userArchivedPostsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Archived Posts')),
      body: archivedPostsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed: $e')),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No archived posts found.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Archived posts will appear here after you archive them from profile or feed.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userArchivedPostsProvider(userId));
              ref.invalidate(userPostsProvider(userId));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final post = posts[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(
                      post.content.trim().isEmpty
                          ? '(no text)'
                          : post.content.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Archived • ${post.createdAt.toLocal()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Open post',
                          onPressed: () => context.push('/post/${post.id}'),
                          icon: const Icon(Icons.open_in_new),
                        ),
                        IconButton(
                          tooltip: 'Restore post',
                          onPressed: () async {
                            await ref
                                .read(postRepositoryProvider)
                                .unarchivePost(post.id);
                            ref.invalidate(userArchivedPostsProvider(userId));
                            ref.invalidate(userPostsProvider(userId));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Post restored to published.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.unarchive_outlined),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
