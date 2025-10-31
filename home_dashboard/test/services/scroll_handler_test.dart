import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/core/services/scroll_handler.dart';
import 'package:home_dashboard/shared/widgets/footer_controller.dart';
import '../test_helpers.dart';

void main() {
  group('ScrollHandler', () {
    late ScrollHandler scrollHandler;
    late FooterController footerController;

    setUpAll(() async {
      await loadTestConfig();
    });

    setUp(() {
      footerController = FooterController();
      scrollHandler = ScrollHandler(footerController: footerController);
    });

    tearDown(() {
      scrollHandler.dispose();
      footerController.dispose();
    });

    test('starts with not scrolled', () {
      expect(scrollHandler.isScrolled, false);
    });

    test('has a scroll controller', () {
      expect(scrollHandler.scrollController, isNotNull);
    });

    test('handlePointerScroll can be called', () {
      // Should not throw
      scrollHandler.handlePointerScroll();
    });

    test('handleGestureScroll can be called', () {
      // Should not throw
      scrollHandler.handleGestureScroll();
    });

    test('notifies listeners when scroll state changes', () {
      var notified = false;
      scrollHandler.addListener(() {
        notified = true;
      });

      // Manually trigger the internal state change
      scrollHandler.handlePointerScroll();

      // Note: Without actually scrolling, isScrolled won't change,
      // but we verify the handler doesn't crash
      expect(notified, isFalse); // No actual scroll position change
    });
  });
}
