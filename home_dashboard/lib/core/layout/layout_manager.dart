import 'package:flutter/material.dart';
import '../constants/navigation_config.dart';

/// Determines which layout mode to use based on screen width
enum LayoutMode {
  tiny, // < 600px: drawer only, minimal appbar
  small, // 600-960px: drawer with transitions
  medium, // 960-1535px: rail with optional child drawer
  desktop, // >= 1535px: rail with persistent child drawer
}

/// Manages responsive layout state and transitions
class LayoutManager extends ChangeNotifier {
  double _lastWidth = 0;
  LayoutMode _currentMode = LayoutMode.tiny;

  LayoutMode get currentMode => _currentMode;
  double get lastWidth => _lastWidth;

  /// Determine layout mode from screen width
  static LayoutMode modeFromWidth(double width) {
    if (width < Breakpoints.mobileTiny) {
      return LayoutMode.tiny;
    } else if (width < Breakpoints.mobileSmall) {
      return LayoutMode.small;
    } else if (width < Breakpoints.desktop) {
      return LayoutMode.medium;
    } else {
      return LayoutMode.desktop;
    }
  }

  /// Update layout based on new width and handle transitions
  /// Returns true if there was a significant layout mode change
  bool updateLayout(double width) {
    final newMode = modeFromWidth(width);
    final modeChanged = newMode != _currentMode;

    _lastWidth = width;
    _currentMode = newMode;

    if (modeChanged) {
      notifyListeners();
    }

    return modeChanged;
  }

  /// Check if transitioning from smaller to larger breakpoint
  bool shouldCloseDrawersOnExpand(double oldWidth, double newWidth) {
    return (oldWidth < Breakpoints.mobileSmall &&
            newWidth >= Breakpoints.mobileSmall) ||
        (oldWidth < Breakpoints.desktop && newWidth >= Breakpoints.desktop);
  }

  /// Check if transitioning from desktop to medium (should close child drawer)
  bool shouldCloseChildDrawerOnShrink(double oldWidth, double newWidth) {
    return oldWidth >= Breakpoints.desktop && newWidth < Breakpoints.desktop;
  }
}
