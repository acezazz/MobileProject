import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/report_model.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
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
}) {
  final isSplashRoute = matchedLocation == '/splash';
  final isGuestLandingRoute = matchedLocation == '/landing';
  final isPublicBrowseRoute = matchedLocation == '/';
  final isPostDetailRoute = matchedLocation.startsWith('/post/');
  final isAuthRoute =
      matchedLocation == '/login' || matchedLocation == '/register';

  if (isSplashRoute) {
    return null;
  }

  if (isLoadingAuth) {
    return null;
  }

  if (!isLoggedIn) {
    final isGuestAllowed =
        isGuestLandingRoute ||
        isPublicBrowseRoute ||
        isPostDetailRoute ||
        isAuthRoute ||
        isSplashRoute;
    if (!isGuestAllowed) {
      final from = Uri.encodeComponent(uri.toString());
      return '/login?from=$from';
    }
  }

  if (isLoggedIn && (isAuthRoute || isGuestLandingRoute)) {
    return '/';
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      return resolveAppRedirect(
        isLoggedIn: authState.valueOrNull != null,
        isLoadingAuth: authState.isLoading,
        matchedLocation: state.matchedLocation,
        uri: state.uri,
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

      // Home (tab navigation)
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),

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
