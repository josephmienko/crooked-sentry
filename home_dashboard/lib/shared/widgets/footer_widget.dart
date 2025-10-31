import 'package:flutter/material.dart';
import '../../core/services/config_service.dart';
import '../../core/constants/navigation_config.dart';
import 'package:url_launcher/url_launcher.dart';

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.config;
    final footer = config.footer;
    if (footer == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoPath = config.brand.getLogoPath(isDarkMode);

    // Styles used by the legal row
    final linkStyle = const TextStyle(
      fontFamily: 'Google Sans Text',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 24.0 / 16.0,
      letterSpacing: 0,
    ).copyWith(color: colorScheme.primary);

    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainer,
      padding: const EdgeInsets.only(left: 60, right: 60, bottom: 5, top: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth; // width inside the padded container
          final viewportW =
              MediaQuery.of(context).size.width; // full viewport width
          const skinny = 335.0;

          // Build legal links
          final legalLinks = footer.links
              .map((l) => GestureDetector(
                    onTap: () => _openUrl(l.url),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 24, bottom: 8),
                      child: Text(l.label, style: linkStyle),
                    ),
                  ))
              .toList();

          // Decide logo visibility by viewport width (not the inner padded width)
          final showLogo =
              viewportW >= Breakpoints.mobileSmall && logoPath.isNotEmpty;
          final logo = showLogo
              ? Image.asset(
                  logoPath,
                  height: 32,
                )
              : const SizedBox.shrink();

          if (w < skinny) {
            // <335px: logo above with all legal links below
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLogo) ...[
                  logo,
                  const SizedBox(height: 40),
                ],
                ...legalLinks,
              ],
            );
          }

          // >=335px: logo on the left, links wrap to the right
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showLogo) ...[
                logo,
                const SizedBox(width: 24),
              ],
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: legalLinks,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
