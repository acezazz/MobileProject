import 'package:flutter/material.dart';

import '../common/avatar_widget.dart';

class MessagePreviewTile extends StatelessWidget {
  final String name;
  final String preview;
  final String timestamp;
  final String? imageUrl;
  final bool isGroup;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MessagePreviewTile({
    super.key,
    required this.name,
    required this.preview,
    required this.timestamp,
    this.imageUrl,
    this.isGroup = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              isGroup
                  ? CircleAvatar(
                      radius: 24,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.group_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : AvatarWidget(imageUrl: imageUrl, name: name, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timestamp,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
