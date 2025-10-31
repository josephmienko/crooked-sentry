import 'package:flutter/material.dart';
import 'widgets/welcome_card.dart';
import '../../shared/widgets/looping_video_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use Row if wide, Column if narrow
          if (constraints.maxWidth > 900) {
            // Calculate card width and corresponding video height for matching
            final cardWidth =
                (constraints.maxWidth - 24 - 48) / 2; // minus padding and gap
            final videoHeight = cardWidth / (16 / 9); // 16:9 aspect ratio
            // Prevent text overflow on the Welcome card near breakpoints
            const double minCardHeight = 320;
            final double cardHeight =
                videoHeight < minCardHeight ? minCardHeight : videoHeight;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: cardHeight,
                    child: const WelcomeCard(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: cardHeight,
                    child: const LoopingVideoCard(
                      videoAssetPath: 'web/videos/home.mp4',
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const WelcomeCard(),
                const SizedBox(height: 12),
                LoopingVideoCard(
                  videoAssetPath: 'web/videos/home.mp4',
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
