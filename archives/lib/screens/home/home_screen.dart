import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/interaction_gate.dart';
import '../../providers/auth_providers.dart';
import '../activity/activity_screen.dart';
import '../feed/feed_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final bool? isGuestModeOverride;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
    this.isGuestModeOverride,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onNavTap(int navIndex) async {
    HapticFeedback.selectionClick();
    if (navIndex == 2) {
      final canOpen = await ensureAuthenticatedForPath(
        context: context,
        ref: ref,
        destinationPath: '/create-post',
      );
      if (!canOpen || !mounted) return;
      context.push('/create-post');
      return;
    }

    setState(() {
      _currentIndex = navIndex > 2 ? navIndex - 1 : navIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isGuestMode = widget.isGuestModeOverride ?? currentUser == null;

    if (isGuestMode) {
      return const Scaffold(body: FeedScreen());
    }

    final profileUserId = currentUser?.uid ?? 'guest';

    final screens = <Widget>[
      const FeedScreen(),
      const SearchScreen(),
      const ActivityScreen(),
      ProfileScreen(userId: profileUserId),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Post',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
