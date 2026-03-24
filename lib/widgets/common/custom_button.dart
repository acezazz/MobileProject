import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'loading_indicator.dart';

class CustomButton extends StatefulWidget {
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
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.isLoading || widget.onPressed == null;
    final scale = _isPressed
        ? 0.985
        : (_isHovering && !isDisabled)
              ? 1.01
              : 1.0;

    if (widget.isOutlined) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() {
          _isHovering = false;
          _isPressed = false;
        }),
        child: GestureDetector(
          onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
          onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            scale: scale,
            child: OutlinedButton(
              onPressed: isDisabled ? null : widget.onPressed,
              child: widget.isLoading
                  ? const LoadingIndicator(size: 20)
                  : Text(widget.text),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() {
        _isHovering = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          scale: scale,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, widget.compact ? 48 : 56),
              backgroundColor: widget.backgroundColor ?? AppColors.accent,
              foregroundColor: widget.foregroundColor ?? Colors.white,
            ).copyWith(
              elevation: WidgetStateProperty.resolveWith<double>((states) {
                if (states.contains(WidgetState.disabled)) return 0;
                if (states.contains(WidgetState.hovered)) return 1.5;
                return 0;
              }),
            ),
            onPressed: isDisabled ? null : widget.onPressed,
            child: widget.isLoading
                ? const LoadingIndicator(size: 20)
                : Text(widget.text),
          ),
        ),
      ),
    );
  }
}
