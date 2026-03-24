import 'package:archives/screens/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('register progresses profile -> credentials', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2: profile details'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Birthdate'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'user_one');

    await tester.tap(find.byType(TextField).at(1));
    await tester.pumpAndSettle();
    if (find.text('OK').evaluate().isNotEmpty) {
      await tester.tap(find.text('OK'));
    } else if (find.text('Confirm').evaluate().isNotEmpty) {
      await tester.tap(find.text('Confirm'));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 2: login credentials'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    expect(find.text('Create account'), findsOneWidget);
  });
}
