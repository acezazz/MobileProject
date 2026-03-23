import 'package:archives/screens/feed/create_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create post pre-fills repost content from repostId query', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CreatePostScreen(repostId: 'post_123')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Repost: /post/post_123'), findsOneWidget);
  });
}
