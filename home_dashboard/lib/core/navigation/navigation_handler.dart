import 'package:flutter/material.dart';
import '../constants/navigation_config.dart';
import '../models/navigation_models.dart';
import 'navigation_state_manager.dart';
import '../../shared/widgets/footer_controller.dart';

/// Handles navigation actions and delegates to NavigationStateManager
///
/// This class consolidates all navigation callback logic and provides
/// a clean interface for navigation actions throughout the app.
class NavigationHandler {
  final NavigationStateManager stateManager;
  final FooterController footerController;
  final List<NavItem> navItems;

  NavigationHandler({
    required this.stateManager,
    required this.footerController,
    List<NavItem>? navItems,
  }) : navItems = navItems ?? NavigationConfig.items;

  /// Handle tap on a main navigation item (drawer on mobile)
  void onNavTap(int index, BuildContext context) {
    if (navItems[index].hasChildren) {
      // Parent will handle showing child menu dialog
      return;
    }
    stateManager.navigateTo(index, context, navItems);
    footerController.hideFooter();
    Navigator.of(context).pop(); // Close drawer
  }

  /// Handle tap on a main navigation item with child drawer support (rail on desktop)
  void onNavTapWithDrawer(int index, BuildContext context, double width) {
    stateManager.navigateToWithDrawer(index, context, navItems, width);
    footerController.hideFooter();
  }

  /// Handle tap on a child navigation item
  void onChildTap(int childIndex, BuildContext context) {
    Navigator.of(context).pop(); // Close dialog/drawer
    stateManager.navigateToChild(childIndex, context);
    footerController.hideFooter();
  }

  /// Handle tap on a grandchild navigation item
  void onGrandchildTap(
    int childIndex,
    int grandchildIndex,
    BuildContext context,
  ) {
    Navigator.of(context).pop(); // Close dialog/drawer
    stateManager.navigateToGrandchild(childIndex, grandchildIndex, context);
    footerController.hideFooter();
  }

  /// Handle tap on brand/logo
  void onBrandTap(BuildContext context) {
    stateManager.navigateTo(0, context, navItems);
    footerController.hideFooter();
  }

  /// Check if a navigation item has children that need special handling
  bool shouldShowChildMenu(int index) {
    return navItems[index].hasChildren;
  }
}
