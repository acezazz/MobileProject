import 'package:archives/core/navigation/interaction_gate.dart';
import 'package:archives/models/interaction_intent.dart';
import 'package:archives/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guest tap on gated action opens center login dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: _GateHarness()),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Register'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

class _GateHarness extends ConsumerWidget {
  const _GateHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          ensureAuthenticatedForIntent(
            context: context,
            ref: ref,
            intent: const InteractionIntent(
              targetType: InteractionTargetType.post,
              targetId: 'p1',
              action: InteractionAction.like,
            ),
          );
        },
        child: const Text('Tap'),
      ),
    );
  }
}
