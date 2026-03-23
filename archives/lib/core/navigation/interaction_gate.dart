import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/interaction_intent.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/auth/interaction_login_dialog.dart';

Future<bool> ensureAuthenticatedForIntent({
  required BuildContext context,
  required WidgetRef ref,
  required InteractionIntent intent,
}) async {
  final user = ref.read(authStateProvider).valueOrNull;
  if (user != null) {
    return true;
  }

  final choice = await showDialog<InteractionLoginChoice>(
    context: context,
    builder: (_) => const InteractionLoginDialog(),
  );

  if (!context.mounted) {
    return false;
  }

  if (choice == InteractionLoginChoice.login) {
    context.go(
      Uri(path: '/login', queryParameters: intent.toQueryMap()).toString(),
    );
  }

  return false;
}

Future<bool> ensureAuthenticatedForPath({
  required BuildContext context,
  required WidgetRef ref,
  required String destinationPath,
}) async {
  final user = ref.read(authStateProvider).valueOrNull;
  if (user != null) {
    return true;
  }

  final choice = await showDialog<InteractionLoginChoice>(
    context: context,
    builder: (_) => const InteractionLoginDialog(),
  );

  if (!context.mounted) {
    return false;
  }

  if (choice == InteractionLoginChoice.login) {
    final from = Uri.encodeComponent(destinationPath);
    context.go('/login?from=$from');
  }

  return false;
}

String resolveIntentPath(InteractionIntent intent) {
  switch (intent.targetType) {
    case InteractionTargetType.post:
      if (intent.action == InteractionAction.comment) {
        return '/post/${intent.targetId}?focus=comments';
      }
      return '/post/${intent.targetId}';
    case InteractionTargetType.chat:
      final messageId = intent.context['messageId'];
      if (messageId != null && messageId.isNotEmpty) {
        return '/chat/${intent.targetId}?messageId=$messageId';
      }
      return '/chat/${intent.targetId}';
  }
}
