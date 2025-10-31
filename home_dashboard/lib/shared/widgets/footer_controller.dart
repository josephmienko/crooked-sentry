import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/app_config.dart';
import '../../core/services/config_service.dart';
import '../../core/constants/navigation_config.dart';

/// Manages footer visibility and auto-hide behavior
class FooterController extends ChangeNotifier {
  bool _showFooter = false;
  bool _smallFooterPrimed = false;
  Timer? _hideFooterTimer;

  bool get showFooter => _showFooter;

  /// Cleanup resources
  @override
  void dispose() {
    _hideFooterTimer?.cancel();
    super.dispose();
  }

  /// Determine current footer mode based on navigation state
  FooterMode getCurrentFooterMode({
    required int selectedIndex,
    int? selectedChild,
    int? selectedGrandchild,
  }) {
    final config = ConfigService.config;
    final navConfig = config.navigationItems;
    final item = navConfig[selectedIndex];

    // If on CC-CC-TV child/grandchild, map to config levels when possible
    if (selectedIndex == 2) {
      if (selectedChild != null && selectedChild < item.children.length) {
        final childCfg = item.children[selectedChild];
        if (selectedGrandchild != null &&
            childCfg.hasGrandchildren &&
            selectedGrandchild < childCfg.children.length) {
          final mode = childCfg.children[selectedGrandchild].footerMode;
          print('[FOOTER] Footer mode (grandchild): $mode');
          return mode;
        }
        final mode = childCfg.footerMode;
        print('[FOOTER] Footer mode (child): $mode');
        return mode;
      }
    }
    final mode = item.footerMode;
    print('[FOOTER] Footer mode (item): $mode, _showFooter: $_showFooter');
    return mode;
  }

  /// Show footer and start auto-hide timer
  void showFooterWithTimer() {
    if (!_showFooter) {
      _showFooter = true;
      notifyListeners();
      print('[SCROLL] Footer shown');
    }

    // Cancel existing timer
    _hideFooterTimer?.cancel();

    // Set timer to hide footer after 3 seconds of inactivity
    _hideFooterTimer = Timer(const Duration(seconds: 3), () {
      _showFooter = false;
      notifyListeners();
      print('[TIMER] Footer hidden after inactivity');
    });
  }

  /// Hide footer immediately
  void hideFooter() {
    _hideFooterTimer?.cancel();
    if (_showFooter) {
      _showFooter = false;
      notifyListeners();
    }
  }

  /// Auto-show footer briefly on small screens
  void maybeAutoShowForSmallScreen(double width) {
    final isSmall = width < Breakpoints.mobileSmall;
    if (isSmall && !_smallFooterPrimed) {
      _smallFooterPrimed = true;
      // Use a post-frame callback to ensure we're not in build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFooter = true;
        notifyListeners();

        _hideFooterTimer?.cancel();
        _hideFooterTimer = Timer(const Duration(seconds: 3), () {
          _showFooter = false;
          notifyListeners();
        });
      });
    } else if (!isSmall) {
      // Reset priming when returning to large screens
      _smallFooterPrimed = false;
    }
  }

  /// Reset priming state
  void resetPriming() {
    _smallFooterPrimed = false;
  }
}
