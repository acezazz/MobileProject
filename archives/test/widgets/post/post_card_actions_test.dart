import 'package:archives/models/post_model.dart';
import 'package:archives/providers/auth_providers.dart';
import 'package:archives/providers/post_providers.dart';
import 'package:archives/providers/user_providers.dart';
import 'package:archives/widgets/post/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('comment action triggers callback', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(),
        child: MaterialApp(
          home: Scaffold(
            body: PostCard(
              post: _post(),
              currentUserIdOverride: 'u_test',
              onCommentTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pumpAndSettle();

    expect(tapped, true);
  });

  testWidgets('guest tap on like opens login dialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _baseOverrides(),
        child: MaterialApp(
          home: Scaffold(body: PostCard(post: _post())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Register'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

List<Override> _baseOverrides() {
  return [
    authStateProvider.overrideWith((ref) => Stream.value(null)),
    postStreamProvider.overrideWith((ref, postId) => Stream.value(null)),
    userProfileProvider.overrideWith((ref, userId) async => null),
    likeStatusProvider.overrideWith((ref, args) => Stream.value(false)),
    postLikesCountProvider.overrideWith((ref, postId) => Stream.value(0)),
    postCommentsCountProvider.overrideWith((ref, postId) => Stream.value(0)),
  ];
}

PostModel _post() {
  return PostModel(
    id: 'p1',
    userId: 'u1',
    userName: 'User One',
    userUsername: 'user1',
    content: 'Hello post',
    createdAt: DateTime(2026, 1, 1),
  );
}
