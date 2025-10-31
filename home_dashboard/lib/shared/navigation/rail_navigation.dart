import 'package:flutter/material.dart';
import '../../core/models/navigation_models.dart';
import '../../core/models/network_type.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/animation_toggle.dart';

/// Navigation rail for desktop screens
class RailNavigation extends StatelessWidget {
  final List<NavItem> navItems;
  final int selectedIndex;
  final ThemeMode themeMode;
  final Function(int) onDestinationSelected;
  final VoidCallback onThemeToggle;
  final NetworkType networkType;
  final bool networkLoaded;
  final VoidCallback? onRefreshNetwork;

  const RailNavigation({
    Key? key,
    required this.navItems,
    required this.selectedIndex,
    required this.themeMode,
    required this.onDestinationSelected,
    required this.onThemeToggle,
    required this.networkType,
    required this.networkLoaded,
    this.onRefreshNetwork,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, bottom: 16.0),
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => onDestinationSelected(index),
          labelType: NavigationRailLabelType.all,
          minWidth: 88,
          backgroundColor: Colors.transparent,
          useIndicator: true,
          indicatorColor: colorScheme.secondaryContainer,
          indicatorShape: const StadiumBorder(),
          leading: _buildNetworkIndicatorLarge(context),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimationToggleCompact(),
                    const SizedBox(height: 16),
                    ThemeToggleCompact(
                      themeMode: themeMode,
                      onToggle: onThemeToggle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          destinations: [
            for (final item in navItems)
              NavigationRailDestination(
                icon: Icon(item.icon, size: 32),
                label: Padding(
                  padding: const EdgeInsets.only(bottom: 14.0),
                  child: Text(item.label),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkIndicatorLarge(BuildContext context) {
    if (!networkLoaded) {
      return const SizedBox(height: 64);
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Determine icon and colors based on network type
    // VPN or WiFi (LAN) → vpn_key with primary colors
    // Internet → vpn_key_off with error colors
    final bool isSecure =
        networkType == NetworkType.wifi || networkType == NetworkType.vpn;

    final IconData icon = isSecure ? Icons.vpn_key : Icons.vpn_key_off;
    final Color backgroundColor =
        isSecure ? colorScheme.primaryContainer : colorScheme.errorContainer;
    final Color iconColor = isSecure
        ? colorScheme.onPrimaryContainer
        : colorScheme.onErrorContainer;

    // Large square tonal icon button (64x64 with rounded corners)
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Tooltip(
        message: '${networkType.label}\nTap to refresh',
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onRefreshNetwork,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child: Icon(icon, color: iconColor, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
