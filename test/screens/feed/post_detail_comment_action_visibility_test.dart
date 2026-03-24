import 'package:archives/models/post_model.dart';
import 'package:archives/providers/auth_providers.dart';
import 'package:archives/providers/post_providers.dart';
import 'package:archives/providers/user_providers.dart';
import 'package:archives/screens/feed/post_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('post detail hides action-row comment icon but keeps composer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userProfileProvider.overrideWith((ref, userId) async => null),
          postStreamProvider.overrideWith(
            (ref, postId) => Stream.value(_post()),
          ),
          commentsProvider.overrideWith((ref, postId) => Stream.value([])),
          postLikesCountProvider.overrideWith((ref, postId) => Stream.value(0)),
          postCommentsCountProvider.overrideWith((ref, postId) => Stream.value(0)),
        ],
        child: const MaterialApp(
          home: PostDetailScreen(postId: 'p1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
    expect(find.text('Write a comment...'), findsOneWidget);
  });
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
