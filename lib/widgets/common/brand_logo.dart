import 'package:flutter/material.dart';

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
    final logoSize = compact ? 84.0 : 138.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/archives_logo_exact.png',
          width: logoSize,
          height: logoSize,
          filterQuality: FilterQuality.high,
        ),
      ],
    );
  }
}
