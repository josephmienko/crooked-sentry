import 'package:flutter/material.dart';
import '../models/navigation_models.dart';
import '../../shared/navigation/child_drawer.dart';

/// Service for showing app-specific dialogs
///
/// Centralizes dialog presentation logic to keep scaffolds and pages clean.
class DialogService {
  /// Show a child navigation menu as a modal dialog
  ///
  /// Used on mobile layouts to display child navigation items when
  /// a parent navigation item with children is tapped.
  static Future<void> showChildMenuDialog({
    required BuildContext context,
    required NavItem parentItem,
    required int parentIndex,
    required int? selectedChildIndex,
    required int? selectedGrandchildIndex,
    required Set<int> expandedChildren,
    required Function(int) onChildTap,
    required Function(int, int) onGrandchildTap,
    required VoidCallback onBack,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            elevation: 16,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: SizedBox(
              width: 304,
              height: double.infinity,
              child: ChildDrawer(
                parentItem: parentItem,
                parentIndex: parentIndex,
                selectedChildIndex: selectedChildIndex,
                selectedGrandchildIndex: selectedGrandchildIndex,
                expandedChildren: expandedChildren,
                onChildTap: onChildTap,
                onGrandchildTap: onGrandchildTap,
                isDialog: true,
                onBack: onBack,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
    );
  }
}
