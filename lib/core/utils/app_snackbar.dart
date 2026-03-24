import 'package:flutter/material.dart';

class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      backgroundColor: const Color(0xFF1F9D55),
      icon: Icons.check_circle_rounded,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      backgroundColor: const Color(0xFFD64545),
      icon: Icons.error_rounded,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      backgroundColor: const Color(0xFF3658A8),
      icon: Icons.info_rounded,
    );
  }

  static void _show({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
