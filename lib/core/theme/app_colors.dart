import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand palette
  static const Color accent = Color(0xFF6C3BAA);
  static const Color secondary = Color(0xFFFFFFFF);

  // Dark mode tokens (priority)
  static const Color background = Color(0xFF130B1F);
  static const Color surface = Color(0xFF201233);
  static const Color surfaceVariant = Color(0xFF2B1845);
  static const Color cardBackground = Color(0xFF201233);

  // Light mode tokens
  static const Color lightBackground = Color(0xFFF8F5FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0E9FF);

  // Legacy aliases kept for compatibility with existing code
  static const Color accentBeige = secondary;
  static const Color accentBeigeMuted = Color(0xFFE3D5FF);
  static const Color inkDark = Color(0xFF261445);

  // Text
  static const Color textPrimary = Color(0xFFF7F3FF);
  static const Color textSecondary = Color(0xFFC6B6E6);
  static const Color textHint = Color(0xFFA692C9);
  static const Color lightTextPrimary = Color(0xFF23153D);
  static const Color lightTextSecondary = Color(0xFF5D4A82);

  // Accent aliases
  static const Color primaryAccent = accent;
  static const Color secondaryAccent = secondary;
  static const Color likeRed = Color(0xFFED4956);
  static const Color onlineGreen = Color(0xFF00D26A);

  // Borders & dividers
  static const Color divider = Color(0xFF3D2A5C);
  static const Color border = Color(0xFF3D2A5C);
  static const Color lightDivider = Color(0xFFDCCFFF);

  // Error / Warning
  static const Color error = Color(0xFFD64545);
  static const Color success = Color(0xFF1F9D55);
  static const Color warning = Color(0xFFF5A524);
}
