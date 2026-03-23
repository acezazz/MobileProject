import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double wordmarkSize;
  final bool compact;

  const BrandLogo({
    super.key,
    this.wordmarkSize = 62,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ornamentWidth = compact ? 110.0 : 170.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ornament(ornamentWidth),
        const SizedBox(height: 10),
        Text(
          'archives',
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.accentBeige,
            fontWeight: FontWeight.w700,
            fontSize: wordmarkSize,
            letterSpacing: 0.6,
            height: 0.92,
          ),
        ),
        const SizedBox(height: 10),
        _ornament(ornamentWidth * 0.75),
      ],
    );
  }

  Widget _ornament(double width) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.accentBeigeMuted, thickness: 1),
          ),
          const SizedBox(width: 8),
          Icon(Icons.diamond, size: 8, color: AppColors.accentBeige),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(color: AppColors.accentBeigeMuted, thickness: 1),
          ),
        ],
      ),
    );
  }
}
