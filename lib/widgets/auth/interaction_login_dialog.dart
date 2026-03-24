import 'package:flutter/material.dart';

enum InteractionLoginChoice { login, cancel }

class InteractionLoginDialog extends StatelessWidget {
  const InteractionLoginDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Login required', textAlign: TextAlign.center),
      content: const Text(
        'You can browse posts as a guest. Login to like, comment, repost, or share.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(InteractionLoginChoice.cancel);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(InteractionLoginChoice.login);
          },
          child: const Text('Login'),
        ),
      ],
    );
  }
}
