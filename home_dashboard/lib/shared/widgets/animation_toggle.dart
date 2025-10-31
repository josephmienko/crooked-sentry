import 'package:flutter/material.dart';
import '../../core/services/animation_service.dart';

class AnimationToggleCompact extends StatelessWidget {
  const AnimationToggleCompact({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Match ThemeToggleCompact: 48x48 circular, 1px outline
    return ValueListenableBuilder<bool>(
      valueListenable: AnimationService.paused,
      builder: (context, paused, _) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.outline,
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            tooltip: paused ? 'Play animations' : 'Pause animations',
            onPressed: AnimationService.toggle,
          ),
        );
      },
    );
  }
}

class AnimationToggleFull extends StatelessWidget {
  const AnimationToggleFull({super.key});

  @override
  Widget build(BuildContext context) {
    // Match ThemeToggleFull: ListTile with rounded (pill) hover/ink and left-aligned icon/text
    return ValueListenableBuilder<bool>(
      valueListenable: AnimationService.paused,
      builder: (context, paused, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            leading: Icon(paused ? Icons.play_arrow : Icons.pause),
            title: Text(paused ? 'Play animations' : 'Pause animations'),
            onTap: AnimationService.toggle,
          ),
        );
      },
    );
  }
}
