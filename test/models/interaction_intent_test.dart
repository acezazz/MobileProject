import 'package:archives/models/interaction_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InteractionIntent round-trips with query map', () {
    final intent = InteractionIntent(
      targetType: InteractionTargetType.post,
      targetId: 'post_1',
      action: InteractionAction.comment,
      context: {'focus': 'comments'},
    );

    final map = intent.toQueryMap();
    final parsed = InteractionIntent.fromQueryMap(map);

    expect(parsed?.targetType, InteractionTargetType.post);
    expect(parsed?.targetId, 'post_1');
    expect(parsed?.action, InteractionAction.comment);
    expect(parsed?.context['focus'], 'comments');
  });
}
