import 'dart:convert';

enum InteractionTargetType { post, chat }

enum InteractionAction { like, comment, repost, share, message }

class InteractionIntent {
  final InteractionTargetType targetType;
  final String targetId;
  final InteractionAction action;
  final Map<String, String> context;

  const InteractionIntent({
    required this.targetType,
    required this.targetId,
    required this.action,
    this.context = const {},
  });

  Map<String, String> toQueryMap() {
    return {
      'it': targetType.name,
      'id': targetId,
      'ia': action.name,
      if (context.isNotEmpty) 'ic': jsonEncode(context),
    };
  }

  static InteractionIntent? fromQueryMap(Map<String, String> query) {
    final typeRaw = query['it'];
    final id = query['id'];
    final actionRaw = query['ia'];

    if (typeRaw == null || id == null || actionRaw == null || id.isEmpty) {
      return null;
    }

    InteractionTargetType? targetType;
    for (final value in InteractionTargetType.values) {
      if (value.name == typeRaw) {
        targetType = value;
        break;
      }
    }

    InteractionAction? action;
    for (final value in InteractionAction.values) {
      if (value.name == actionRaw) {
        action = value;
        break;
      }
    }

    if (targetType == null || action == null) {
      return null;
    }

    var parsedContext = <String, String>{};
    final encodedContext = query['ic'];
    if (encodedContext != null && encodedContext.isNotEmpty) {
      final decoded = jsonDecode(encodedContext);
      if (decoded is Map<String, dynamic>) {
        parsedContext = decoded.map((key, value) => MapEntry(key, '$value'));
      }
    }

    return InteractionIntent(
      targetType: targetType,
      targetId: id,
      action: action,
      context: parsedContext,
    );
  }
}
