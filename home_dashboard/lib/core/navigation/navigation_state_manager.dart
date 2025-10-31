import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/navigation_models.dart';
import '../constants/navigation_config.dart';

/// Manages navigation state including selected indices and drawer visibility
class NavigationStateManager extends ChangeNotifier {
  int _selectedIndex = 0;
  int? _selectedCCChild;
  int? _selectedGrandchild;
  bool _showChildDrawer = false;
  final Set<int> _expandedChildren = {};

  int get selectedIndex => _selectedIndex;
  int? get selectedCCChild => _selectedCCChild;
  int? get selectedGrandchild => _selectedGrandchild;
  bool get showChildDrawer => _showChildDrawer;
  Set<int> get expandedChildren => _expandedChildren;

  /// Navigate to a top-level destination
  void navigateTo(int index, BuildContext context, List<NavItem> navItems) {
    _selectedIndex = index;
    _selectedCCChild = null;
    _selectedGrandchild = null;
    notifyListeners();

    // Navigate using go_router
    switch (index) {
      case 0:
        if (context.mounted) context.go('/');
        break;
      case 1:
        if (context.mounted) context.go('/welcome');
        break;
      case 2:
        if (context.mounted) context.go('/video');
        break;
    }
  }

  /// Navigate to a top-level destination with drawer handling
  void navigateToWithDrawer(
    int index,
    BuildContext context,
    List<NavItem> navItems,
    double screenWidth,
  ) {
    _selectedIndex = index;
    _selectedCCChild = null;
    _selectedGrandchild = null;

    // Show child drawer for items with children in the medium screen range
    if (screenWidth >= Breakpoints.mobileSmall &&
        screenWidth < Breakpoints.desktop) {
      _showChildDrawer = navItems[index].hasChildren;
    }

    notifyListeners();

    // Keep route in sync
    switch (index) {
      case 0:
        if (context.mounted) context.go('/');
        break;
      case 1:
        if (context.mounted) context.go('/welcome');
        break;
      case 2:
        if (context.mounted) context.go('/video');
        break;
    }
  }

  /// Navigate to a child item
  void navigateToChild(int childIndex, BuildContext context) {
    _selectedIndex = 2; // Assuming video section
    _selectedCCChild = childIndex;
    _selectedGrandchild = null;
    notifyListeners();

    // Route to video section (placeholder for specific child routes)
    if (context.mounted) context.go('/video');
  }

  /// Navigate to a grandchild item
  void navigateToGrandchild(
    int childIndex,
    int grandchildIndex,
    BuildContext context,
  ) {
    _selectedIndex = 2; // Assuming video section
    _selectedCCChild = childIndex;
    _selectedGrandchild = grandchildIndex;
    notifyListeners();

    // Route to video section (placeholder for specific grandchild routes)
    if (context.mounted) context.go('/video');
  }

  /// Toggle child drawer visibility
  void toggleChildDrawer(bool show) {
    _showChildDrawer = show;
    notifyListeners();
  }

  /// Close child drawer
  void closeChildDrawer() {
    _showChildDrawer = false;
    notifyListeners();
  }

  /// Toggle expansion state for a child item
  void toggleChildExpansion(int index) {
    if (_expandedChildren.contains(index)) {
      _expandedChildren.remove(index);
    } else {
      _expandedChildren.add(index);
    }
    notifyListeners();
  }
}
