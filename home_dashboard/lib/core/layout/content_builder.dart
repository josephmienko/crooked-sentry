import 'package:flutter/material.dart';
import '../layout/layout_manager.dart';
import '../models/app_config.dart';
import '../services/scroll_handler.dart';
import '../../shared/widgets/footer_widget.dart';
import '../../shared/widgets/footer_controller.dart';

/// Builds scrollable content with footer
class ContentBuilder {
  /// Build content with footer that can be shown/hidden
  static Widget buildWithFooter({
    required Widget child,
    required FooterController footerController,
    required int selectedIndex,
    required int? selectedChild,
    required int? selectedGrandchild,
    required LayoutMode layoutMode,
    required ScrollHandler scrollHandler,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: _buildScrollableContent(
            child: child,
            layoutMode: layoutMode,
            scrollHandler: scrollHandler,
          ),
        ),
        ListenableBuilder(
          listenable: footerController,
          builder: (context, _) {
            final footerMode = footerController.getCurrentFooterMode(
              selectedIndex: selectedIndex,
              selectedChild: selectedChild,
              selectedGrandchild: selectedGrandchild,
            );
            final shouldShow = footerMode == FooterMode.defaultShow &&
                footerController.showFooter;

            return AnimatedOpacity(
              opacity: shouldShow ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child:
                  shouldShow ? const FooterWidget() : const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }

  /// Build scrollable content with appropriate gesture handling
  static Widget _buildScrollableContent({
    required Widget child,
    required LayoutMode layoutMode,
    required ScrollHandler scrollHandler,
  }) {
    // For mobile: wrap in gesture detector to catch taps
    if (layoutMode == LayoutMode.tiny || layoutMode == LayoutMode.small) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => scrollHandler.handleGestureScroll(),
        onPanStart: (_) => scrollHandler.handleGestureScroll(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            scrollHandler.handleGestureScroll();
            return false;
          },
          child: SingleChildScrollView(
            controller: scrollHandler.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            child: child,
          ),
        ),
      );
    }

    // For desktop: just use scroll view
    return SingleChildScrollView(
      controller: scrollHandler.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: child,
    );
  }
}
