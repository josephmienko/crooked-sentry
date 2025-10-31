import 'package:flutter/material.dart';

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Use theme-aware colors and explicit typography to mirror the Material demo,
    // with responsive fallbacks to avoid overflow on narrow cards.

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;

        // Title (Display) sizes by width, mirroring demo scale with a slight bump
        // >=1100: Hero-like (96/100), 900-1099: Display XL (88/96), 600-899: Display L (57/64), <600: Display S (36/44)
        double titleSize;
        double titleLineHeight;
        double titleLetterSpacing;
        FontWeight titleWeight;
        if (w >= 1100) {
          titleSize = 96;
          titleLineHeight = 100;
          titleLetterSpacing = -0.5; // tighter tracking at very large sizes
          titleWeight = FontWeight
              .w600; // slightly bolder to match ~475 w/ display rendering
        } else if (w >= 900) {
          titleSize = 88;
          titleLineHeight = 96;
          titleLetterSpacing = -0.25;
          titleWeight = FontWeight.w500;
        } else if (w >= 600) {
          titleSize = 57;
          titleLineHeight = 64;
          titleLetterSpacing = 0;
          titleWeight = FontWeight.w500;
        } else {
          titleSize = 36;
          titleLineHeight = 44;
          titleLetterSpacing = 0;
          titleWeight = FontWeight.w500;
        }

        // Description sizes: prefer Title L (22/30), fall back on smaller at narrow widths
        double descSize;
        double descLineHeight;
        if (w >= 600) {
          descSize = 22;
          descLineHeight = 30;
        } else {
          descSize =
              16; // Title M/Body L equivalent for compact width to prevent overflow
          descLineHeight = 24;
        }

        final onPrimaryContainer =
            Theme.of(context).colorScheme.onPrimaryContainer;

        // When side-by-side (wider cards), match the video's aspect ratio height
        final bool isSideBySide = w > 350;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: isSideBySide
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Material Design',
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontFamily: 'Google Sans Text',
                                  fontSize: titleSize,
                                  height: titleLineHeight / titleSize,
                                  fontWeight: titleWeight,
                                  letterSpacing: titleLetterSpacing,
                                  color: onPrimaryContainer,
                                ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Material Design 3 is Google's open-source design system for building beautiful, usable products.",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontFamily: 'Google Sans Text',
                              fontSize: descSize,
                              height: descLineHeight / descSize,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Get started'),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Material Design',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontFamily: 'Google Sans Text',
                            fontSize: titleSize,
                            height: titleLineHeight / titleSize,
                            fontWeight: titleWeight,
                            letterSpacing: titleLetterSpacing,
                            color: onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Material Design 3 is Google's open-source design system for building beautiful, usable products.",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontFamily: 'Google Sans Text',
                            fontSize: descSize,
                            height: descLineHeight / descSize,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            color: onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Get started'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
