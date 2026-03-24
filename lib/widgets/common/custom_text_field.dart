import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;
  final Color? fillColor;
  final Color? textColor;
  final Color? hintColor;

  const CustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.validator,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.textInputAction,
    this.fillColor,
    this.textColor,
    this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: labelText ?? hintText ?? 'Text Field',
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        enabled: enabled,
        onChanged: onChanged,
        textInputAction: textInputAction,
        style: TextStyle(color: textColor ?? AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          fillColor: fillColor,
          hintStyle: TextStyle(color: hintColor ?? AppColors.textHint),
        ),
      ),
    );
  }
}
