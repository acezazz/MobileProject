import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/role_utils.dart';
import '../models/report_model.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_login_screen.dart';
import '../screens/admin/admin_archives_screen.dart';
import '../screens/admin/admin_posts_screen.dart';
import '../screens/admin/admin_reports_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/suspended_account_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/chats_list_screen.dart';
import '../screens/chat/new_chat_screen.dart';
import '../screens/feed/create_post_screen.dart';
import '../screens/feed/post_detail_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/landing/guest_landing_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/followers_screen.dart';
import '../screens/profile/following_screen.dart';
import '../screens/profile/my_archived_posts_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/report/report_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';
import 'auth_providers.dart';

String? resolveAppRedirect({
  required bool isLoggedIn,
  required bool isLoadingAuth,
  required String matchedLocation,
  required Uri uri,
  String? currentUserRole,
  bool isSuspended = false,
  bool isLoadingProfile = false,
}) {
  final isSplashRoute = matchedLocation == '/splash';
  final isGuestLandingRoute = matchedLocation == '/landing';
  final isPublicBrowseRoute = matchedLocation == '/';
  final isPostDetailRoute = matchedLocation.startsWith('/post/');
  final isAdminLoginRoute = matchedLocation == '/admin-login';
  final isSuspendedRoute = matchedLocation == '/suspended';
  final isAuthRoute =
      matchedLocation == '/login' || matchedLocation == '/register';
  final isAdminRoute =
      matchedLocation == '/admin' || matchedLocation.startsWith('/admin/');

  if (isSplashRoute) {
    return null;
  }

  if (isLoadingAuth) {
    return null;
  }

  if (isLoggedIn && isLoadingProfile) {
    return null;
  }

  if (isLoggedIn && isSuspended) {
    final allowedSuspendedLocation =
        isSuspendedRoute || isAuthRoute || isSplashRoute;
    if (!allowedSuspendedLocation) {
      return '/suspended';
    }
  }

  if (!isLoggedIn) {
    final isGuestAllowed =
        isGuestLandingRoute ||
        isPublicBrowseRoute ||
        isPostDetailRoute ||
        isSuspendedRoute ||
        isAdminLoginRoute ||
        isAuthRoute ||
        isSplashRoute;
    if (!isGuestAllowed) {
      final from = Uri.encodeComponent(uri.toString());
      return '/login?from=$from';
    }
  }

  if (isLoggedIn && !isSuspended && isSuspendedRoute) {
    return '/';
  }

  final isAdminUser = isAdminOrHigher(currentUserRole);

  if (isLoggedIn && isAdminUser) {
    final isAllowedAdminLocation =
        isAdminRoute || isAdminLoginRoute || isSplashRoute || isPostDetailRoute;
    if (!isAllowedAdminLocation) {
      return '/admin';
    }
  }

  if (isLoggedIn && isAdminRoute && !isAdminOrHigher(currentUserRole)) {
    return '/';
  }

  if (isLoggedIn && isAdminLoginRoute) {
    return isAdminOrHigher(currentUserRole) ? '/admin' : '/';
  }

  if (isLoggedIn && (isAuthRoute || isGuestLandingRoute)) {
    return '/';
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(currentUserProfileProvider);
  final currentRole = ref.watch(currentUserRoleProvider);
  final isSuspended = ref.watch(currentUserSuspendedProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      return resolveAppRedirect(
        isLoggedIn: authState.valueOrNull != null,
        isLoadingAuth: authState.isLoading,
        matchedLocation: state.matchedLocation,
        uri: state.uri,
        currentUserRole: currentRole,
        isSuspended: isSuspended,
        isLoadingProfile: profileState.isLoading,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: '/landing',
        builder: (context, state) => const GuestLandingScreen(),
      ),

      // Auth
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/admin-login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/suspended',
        builder: (context, state) => const SuspendedAccountScreen(),
      ),

      // Home (tab navigation)
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/activity',
        builder: (context, state) => const ActivityScreen(),
      ),

      // Post routes
      GoRoute(
        path: '/create-post',
        builder: (context, state) =>
            CreatePostScreen(repostId: state.uri.queryParameters['repostId']),
      ),
      GoRoute(
        path: '/post/:postId',
        builder: (context, state) => PostDetailScreen(
          postId: state.pathParameters['postId']!,
          focusComments: state.uri.queryParameters['focus'] == 'comments',
        ),
      ),

      // Profile routes
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) =>
            ProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/my-archives',
        builder: (context, state) => const MyArchivedPostsScreen(),
      ),
      GoRoute(
        path: '/followers/:userId',
        builder: (context, state) =>
            FollowersScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/following/:userId',
        builder: (context, state) =>
            FollowingScreen(userId: state.pathParameters['userId']!),
      ),

      // Chat routes
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatsListScreen(),
      ),
      GoRoute(
        path: '/chat/new-select',
        builder: (context, state) => const NewChatScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (context, state) => ChatScreen(
          chatId: state.pathParameters['chatId']!,
          highlightedMessageId: state.uri.queryParameters['messageId'],
        ),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Admin routes
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (context, state) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/posts',
        builder: (context, state) => const AdminPostsScreen(),
      ),
      GoRoute(
        path: '/admin/archives',
        builder: (context, state) => const AdminArchivesScreen(),
      ),

      // Report routes
      GoRoute(
        path: '/report/user/:id',
        builder: (context, state) => ReportScreen(
          type: ReportType.user,
          reportedId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/report/post/:id',
        builder: (context, state) => ReportScreen(
          type: ReportType.post,
          reportedId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
