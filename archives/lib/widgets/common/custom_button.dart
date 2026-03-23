import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'loading_indicator.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool compact;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.compact = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const LoadingIndicator(size: 20) : Text(text),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, compact ? 46 : 52),
        backgroundColor: backgroundColor ?? AppColors.accentBeigeMuted,
        foregroundColor: foregroundColor ?? AppColors.inkDark,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading ? const LoadingIndicator(size: 20) : Text(text),
    );
  }
}
