import 'package:archives/core/navigation/interaction_gate.dart';
import 'package:archives/models/interaction_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest intent can be resolved to post route after auth', () {
    final intent = InteractionIntent(
      targetType: InteractionTargetType.post,
      targetId: 'post_1',
      action: InteractionAction.comment,
      context: const {'focus': 'comments'},
    );

    final parsed = InteractionIntent.fromQueryMap(intent.toQueryMap());

    expect(parsed, isNotNull);
    expect(resolveIntentPath(parsed!), '/post/post_1?focus=comments');
  });
}
