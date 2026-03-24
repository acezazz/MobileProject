import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      highlightColor: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class PostCardSkeleton extends StatelessWidget {
  final int delay;

  const PostCardSkeleton({super.key, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final clamped = value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, (1 - clamped) * 12),
          child: Opacity(opacity: clamped, child: child),
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  SkeletonBox(
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120, height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 84, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              SkeletonBox(width: double.infinity, height: 12),
              SizedBox(height: 8),
              SkeletonBox(width: double.infinity, height: 12),
              SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) =>
                    SkeletonBox(width: constraints.maxWidth * 0.6, height: 12),
              ),
              SizedBox(height: 14),
              SkeletonBox(width: double.infinity, height: 180),
              SizedBox(height: 14),
              Row(
                children: [
                  SkeletonBox(
                    width: 24,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  SizedBox(width: 12),
                  SkeletonBox(
                    width: 24,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
