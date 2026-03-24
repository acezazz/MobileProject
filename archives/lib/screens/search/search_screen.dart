import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user_model.dart';
import '../../providers/user_providers.dart';
import '../../widgets/common/avatar_widget.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recommendedAsync = ref.watch(recommendedUsersProvider);
    final usersAsync = _query.trim().isEmpty
        ? const AsyncValue.data(<UserModel>[])
        : ref.watch(searchUsersProvider(_query));
    final excludeFollowed = ref.watch(excludeFollowedRecommendationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recommendedUsersProvider);
          if (_query.trim().isNotEmpty) {
            ref.invalidate(searchUsersProvider(_query));
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            SearchBar(
              controller: _searchController,
              hintText: 'Search users',
              leading: const Icon(Icons.search),
              trailing: _query.trim().isEmpty
                  ? null
                  : [
                      IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: excludeFollowed,
              onChanged: (value) {
                ref
                        .read(excludeFollowedRecommendationsProvider.notifier)
                        .state =
                    value;
              },
              title: const Text('Hide users I already follow'),
            ),
            const SizedBox(height: 8),
            Text(
              _query.trim().isEmpty ? 'Recommended' : 'Results',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_query.trim().isEmpty)
              _usersSection(
                usersAsync: recommendedAsync,
                emptyMessage: 'No recommendations available yet.',
              )
            else
              _usersSection(
                usersAsync: usersAsync,
                emptyMessage: 'No users match your search.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _usersSection({
    required AsyncValue<List<UserModel>> usersAsync,
    required String emptyMessage,
  }) {
    return usersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Could not load users: $e'),
      ),
      data: (users) {
        final visibleUsers = users
            .where((user) => user.role.toLowerCase() != 'admin')
            .toList();

        if (visibleUsers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(emptyMessage),
          );
        }

        return Column(
          children: visibleUsers
              .map(
                (user) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    onTap: () => context.push('/profile/${user.uid}'),
                    leading: AvatarWidget(
                      imageUrl: user.profilePhoto,
                      name: user.name,
                      radius: 22,
                    ),
                    title: Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text('@${user.username}'),
                    trailing: Text(
                      '${user.followersCount}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
