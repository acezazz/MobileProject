import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class EmojiReactionPicker extends StatelessWidget {
  final ValueChanged<String> onSelected;

  // Kept for hot-reload compatibility after replacing the hardcoded grid.
  // ignore: unused_field
  static const List<String> _emojis = <String>[];

  const EmojiReactionPicker({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final picker = Container(
          color: scheme.surface,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) => onSelected(emoji.emoji),
            config: Config(checkPlatformCompatibility: true),
          ),
        );

        if (hasBoundedHeight) return picker;

        // Modal sheets without explicit constraints can collapse this widget.
        return SizedBox(height: 360, child: picker);
      },
    );
  }
}
