import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Neutral + single accent palette
  static const Color accent = Color(0xFF3B82F6);

  // Dark mode tokens (priority)
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceVariant = Color(0xFF21262D);
  static const Color cardBackground = Color(0xFF161B22);

  // Light mode tokens
  static const Color lightBackground = Color(0xFFF6F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEAEFF4);

  // Legacy aliases kept for compatibility with existing code
  static const Color accentBeige = Color(0xFFE8F1FF);
  static const Color accentBeigeMuted = Color(0xFFBFD8FF);
  static const Color inkDark = Color(0xFF111827);

  // Text
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF9DA7B3);
  static const Color textHint = Color(0xFF7D8590);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);

  // Accent aliases
  static const Color primaryAccent = accent;
  static const Color secondaryAccent = accent;
  static const Color likeRed = Color(0xFFED4956);
  static const Color onlineGreen = Color(0xFF00D26A);

  // Borders & dividers
  static const Color divider = Color(0xFF30363D);
  static const Color border = Color(0xFF30363D);
  static const Color lightDivider = Color(0xFFD0D7DE);

  // Error / Warning
  static const Color error = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFF5A524);
}
