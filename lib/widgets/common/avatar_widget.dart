import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? name;

  const AvatarWidget({super.key, this.imageUrl, this.radius = 20, this.name});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceVariant,
      child: hasImage
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!.trim(),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => _fallbackAvatar(),
                errorWidget: (context, url, error) => _fallbackAvatar(),
              ),
            )
          : _fallbackAvatar(),
    );
  }

  Widget _fallbackAvatar() {
    return Icon(Icons.person, size: radius, color: AppColors.textHint);
  }
}
