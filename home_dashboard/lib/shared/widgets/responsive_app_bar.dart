import 'package:flutter/material.dart';
import '../../core/models/network_type.dart';
import '../../core/services/config_service.dart';

/// A responsive app bar with brand logo/name and network indicator
class ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isScrolled;
  final NetworkType networkType;
  final bool networkLoaded;
  final VoidCallback? onRefreshNetwork;
  final VoidCallback? onBrandTap;

  const ResponsiveAppBar({
    Key? key,
    required this.isScrolled,
    required this.networkType,
    required this.networkLoaded,
    this.onRefreshNetwork,
    this.onBrandTap,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: 64,
      backgroundColor:
          isScrolled ? colorScheme.surfaceContainer : colorScheme.surface,
      leading: Padding(
        padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
        child: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
              maxWidth: 48,
              maxHeight: 48,
            ),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(48, 48),
            ),
          ),
        ),
      ),
      title: _buildAppBarTitle(context),
      titleSpacing: 8,
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _buildNetworkIndicator(context),
        ),
      ],
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    final config = ConfigService.config;
    final brand = config.brand;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoPath = brand.getLogoPath(isDarkMode);

    final hasLogo = logoPath.isNotEmpty;
    final hasName = brand.name.isNotEmpty;

    if (!hasLogo && !hasName) {
      return const SizedBox.shrink();
    }

    // Build the inner content (logo, name, or both)
    Widget content;
    if (hasLogo && hasName) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            logoPath,
            width: 48,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 4),
          Text(
            brand.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      );
    } else if (hasLogo) {
      content = Image.asset(
        logoPath,
        width: 48,
        fit: BoxFit.contain,
      );
    } else {
      content = Text(
        brand.name,
        style: Theme.of(context).textTheme.titleLarge,
      );
    }

    // Wrap content in a stadium (pill) hover container
    final overlayColor =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.08);
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const StadiumBorder(),
          hoverColor: overlayColor,
          splashColor: overlayColor,
          onTap: onBrandTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkIndicator(BuildContext context) {
    if (!networkLoaded) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Determine icon and colors based on network type
    final bool isSecure =
        networkType == NetworkType.wifi || networkType == NetworkType.vpn;

    final IconData icon = isSecure ? Icons.vpn_key : Icons.vpn_key_off;
    final Color backgroundColor =
        isSecure ? colorScheme.primaryContainer : colorScheme.errorContainer;
    final Color iconColor = isSecure
        ? colorScheme.onPrimaryContainer
        : colorScheme.onErrorContainer;

    return Tooltip(
      message: '${networkType.label}\nTap to refresh',
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onRefreshNetwork,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
