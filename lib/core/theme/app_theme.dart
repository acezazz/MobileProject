import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  static const double space1 = 8;
  static const double space2 = 16;
  static const double space3 = 24;

  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: AppColors.accent,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      surfaceContainer: AppColors.lightSurfaceVariant,
      onPrimary: Colors.white,
      onSecondary: AppColors.inkDark,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      outline: AppColors.lightDivider,
      error: AppColors.error,
    );

    return _buildTheme(
      scheme: scheme,
      scaffold: AppColors.lightBackground,
      divider: AppColors.lightDivider,
      overlayStyle: SystemUiOverlayStyle.dark,
      isDark: false,
    );
  }

  static ThemeData get darkTheme {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      surfaceContainer: AppColors.surfaceVariant,
      onPrimary: Colors.white,
      onSecondary: AppColors.inkDark,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.divider,
      error: AppColors.error,
    );

    return _buildTheme(
      scheme: scheme,
      scaffold: AppColors.background,
      divider: AppColors.divider,
      overlayStyle: SystemUiOverlayStyle.light,
      isDark: true,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffold,
    required Color divider,
    required SystemUiOverlayStyle overlayStyle,
    required bool isDark,
  }) {
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final sourceText = GoogleFonts.manropeTextTheme(base.textTheme);

    final textTheme = sourceText.copyWith(
      headlineLarge: sourceText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineMedium: sourceText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: sourceText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: sourceText.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: sourceText.bodyLarge?.copyWith(
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: sourceText.bodyMedium?.copyWith(
        height: 1.35,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: sourceText.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      labelMedium: sourceText.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      bodySmall: sourceText.bodySmall?.copyWith(
        color: isDark ? AppColors.textHint : AppColors.lightTextSecondary,
        fontSize: 12,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 0.7),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: divider.withValues(alpha: 0.65)),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: space2,
          vertical: space1,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        tileColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceVariant : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.textHint : AppColors.lightTextSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          animationDuration: const Duration(milliseconds: 180),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          side: BorderSide(color: divider),
          animationDuration: const Duration(milliseconds: 180),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        backgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            size: 26,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceVariant : AppColors.inkDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
