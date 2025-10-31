import 'package:flutter/material.dart';
import '../models/navigation_models.dart';
import '../models/network_type.dart';
import '../../shared/navigation/drawer_navigation.dart';
import '../../shared/navigation/rail_navigation.dart';
import '../../shared/navigation/child_drawer.dart';
import '../../shared/widgets/responsive_app_bar.dart';

/// Builds mobile (drawer-based) layout
class MobileLayoutBuilder {
  /// Build the mobile layout with AppBar and Drawer
  static Widget build({
    required BuildContext context,
    required GlobalKey<ScaffoldState> scaffoldKey,
    required bool isScrolled,
    required NetworkType networkType,
    required bool networkLoaded,
    required VoidCallback? onRefreshNetwork,
    required VoidCallback onBrandTap,
    required List<NavItem> navItems,
    required int selectedIndex,
    required ThemeMode themeMode,
    required Function(int) onNavTap,
    required VoidCallback onThemeToggle,
    required Widget body,
  }) {
    return Scaffold(
      key: scaffoldKey,
      appBar: ResponsiveAppBar(
        isScrolled: isScrolled,
        networkType: networkType,
        networkLoaded: networkLoaded,
        onRefreshNetwork: onRefreshNetwork,
        onBrandTap: onBrandTap,
      ),
      drawer: DrawerNavigation(
        navItems: navItems,
        selectedIndex: selectedIndex,
        themeMode: themeMode,
        onNavTap: onNavTap,
        onThemeToggle: onThemeToggle,
      ),
      body: body,
    );
  }
}

/// Builds desktop (rail-based) layout with optional child drawer
class DesktopLayoutBuilder {
  /// Build the desktop layout with NavigationRail and optional child drawer
  static Widget build({
    required BuildContext context,
    required double width,
    required List<NavItem> navItems,
    required int selectedIndex,
    required ThemeMode themeMode,
    required Function(int) onDestinationSelected,
    required VoidCallback onThemeToggle,
    required NetworkType networkType,
    required bool networkLoaded,
    required VoidCallback? onRefreshNetwork,
    required bool shouldShowChildDrawer,
    required int? selectedChildIndex,
    required int? selectedGrandchildIndex,
    required Set<int> expandedChildren,
    required Function(int) onChildTap,
    required Function(int, int) onGrandchildTap,
    required VoidCallback? onChildDrawerBack,
    required Widget body,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          RailNavigation(
            navItems: navItems,
            selectedIndex: selectedIndex,
            themeMode: themeMode,
            onDestinationSelected: onDestinationSelected,
            onThemeToggle: onThemeToggle,
            networkType: networkType,
            networkLoaded: networkLoaded,
            onRefreshNetwork: onRefreshNetwork,
          ),
          if (shouldShowChildDrawer)
            SizedBox(
              width: 240,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: ChildDrawer(
                  parentItem: navItems[2], // TODO: Make this dynamic
                  parentIndex: 2,
                  selectedChildIndex: selectedChildIndex,
                  selectedGrandchildIndex: selectedGrandchildIndex,
                  expandedChildren: expandedChildren,
                  onChildTap: onChildTap,
                  onGrandchildTap: onGrandchildTap,
                  isDialog: false,
                  onBack: onChildDrawerBack,
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
