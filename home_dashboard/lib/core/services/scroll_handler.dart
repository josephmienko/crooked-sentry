import 'package:flutter/material.dart';
import '../../shared/widgets/footer_controller.dart';

/// Manages scroll state and interactions
///
/// Tracks scroll position for UI updates (like AppBar elevation) and
/// coordinates with FooterController for footer auto-hide behavior.
class ScrollHandler extends ChangeNotifier {
  final ScrollController scrollController;
  final FooterController footerController;

  bool _isScrolled = false;

  ScrollHandler({
    required this.footerController,
  }) : scrollController = ScrollController() {
    scrollController.addListener(_onScroll);
  }

  /// Whether the scroll view is currently scrolled past the top
  bool get isScrolled => _isScrolled;

  /// Handle scroll events
  void _onScroll() {
    // Track scroll position for AppBar color change
    final nowScrolled =
        scrollController.hasClients && scrollController.offset > 0;

    if (nowScrolled != _isScrolled) {
      _isScrolled = nowScrolled;
      notifyListeners();
    }

    // Show footer with auto-hide timer
    footerController.showFooterWithTimer();
  }

  /// Manually trigger scroll handling (for pointer events)
  void handlePointerScroll() {
    _onScroll();
  }

  /// Manually trigger scroll handling (for gesture events)
  void handleGestureScroll() {
    _onScroll();
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }
}
