import 'package:archives/providers/auth_providers.dart';
import 'package:archives/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logged-in home keeps post destination and no FAB', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(
          home: HomeScreen(initialIndex: 1, isGuestModeOverride: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
  });
}
