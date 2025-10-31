import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/shared/widgets/footer_controller.dart';
import 'package:home_dashboard/core/models/app_config.dart';
import 'package:home_dashboard/core/services/config_service.dart';
import '../test_helpers.dart';

void main() {
  group('FooterController', () {
    late FooterController controller;

    setUpAll(() async {
      await loadTestConfig();
    });

    setUp(() {
      controller = FooterController();
    });

    tearDown(() {
      controller.dispose();
    });

    group('showFooterWithTimer', () {
      test('shows footer', () {
        expect(controller.showFooter, false);
        controller.showFooterWithTimer();
        expect(controller.showFooter, true);
      });

      test('notifies listeners when showing footer', () {
        var notified = false;
        controller.addListener(() {
          notified = true;
        });

        controller.showFooterWithTimer();
        expect(notified, true);
      });

      test('does not notify if footer already shown', () {
        controller.showFooterWithTimer();
        var notifyCount = 0;
        controller.addListener(() {
          notifyCount++;
        });

        controller.showFooterWithTimer();
        // Should still notify because timer is reset
        expect(notifyCount, 0); // Only internal state, no notification needed
      });

      test('hides footer after timeout', () async {
        controller.showFooterWithTimer();
        expect(controller.showFooter, true);

        await Future.delayed(const Duration(seconds: 4));
        expect(controller.showFooter, false);
      });
    });

    group('hideFooter', () {
      test('hides footer immediately', () {
        controller.showFooterWithTimer();
        expect(controller.showFooter, true);

        controller.hideFooter();
        expect(controller.showFooter, false);
      });

      test('notifies listeners when hiding footer', () {
        controller.showFooterWithTimer();
        var notified = false;
        controller.addListener(() {
          notified = true;
        });

        controller.hideFooter();
        expect(notified, true);
      });

      test('does nothing if footer already hidden', () {
        expect(controller.showFooter, false);
        var notified = false;
        controller.addListener(() {
          notified = true;
        });

        controller.hideFooter();
        expect(notified, false);
      });
    });

    group('getCurrentFooterMode', () {
      test('returns footer mode for top-level item', () {
        final mode = controller.getCurrentFooterMode(
          selectedIndex: 0,
        );
        expect(mode, isA<FooterMode>());
      });

      test('returns footer mode for child item', () {
        final config = ConfigService.config;
        // Test with video section (index 2) which has children
        if (config.navigationItems.length > 2 &&
            config.navigationItems[2].children.isNotEmpty) {
          final mode = controller.getCurrentFooterMode(
            selectedIndex: 2,
            selectedChild: 0,
          );
          expect(mode, isA<FooterMode>());
        }
      });

      test('returns footer mode for grandchild item', () {
        final config = ConfigService.config;
        // Test with video section that might have grandchildren
        if (config.navigationItems.length > 2 &&
            config.navigationItems[2].children.isNotEmpty &&
            config.navigationItems[2].children[0].hasGrandchildren) {
          final mode = controller.getCurrentFooterMode(
            selectedIndex: 2,
            selectedChild: 0,
            selectedGrandchild: 0,
          );
          expect(mode, isA<FooterMode>());
        }
      });
    });

    group('maybeAutoShowForSmallScreen', () {
      test('shows footer on first small screen detection', () async {
        controller.maybeAutoShowForSmallScreen(500); // small screen

        // Wait for post-frame callback
        await Future.delayed(const Duration(milliseconds: 100));
        expect(controller.showFooter, true);
      });

      test('does not show footer for large screens', () async {
        controller.maybeAutoShowForSmallScreen(1200); // large screen

        await Future.delayed(const Duration(milliseconds: 100));
        expect(controller.showFooter, false);
      });

      test('resets priming when returning to large screen', () async {
        // Show on small screen
        controller.maybeAutoShowForSmallScreen(500);
        await Future.delayed(const Duration(milliseconds: 100));

        // Hide by going to large screen
        controller.maybeAutoShowForSmallScreen(1200);

        // Should be able to trigger again
        controller.maybeAutoShowForSmallScreen(500);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(controller.showFooter, true);
      });
    });

    group('resetPriming', () {
      test('resets priming state', () {
        controller.resetPriming();
        // Should not throw or cause issues
        expect(controller.showFooter, false);
      });
    });

    group('dispose', () {
      test('cleans up resources', () {
        controller.showFooterWithTimer();
        controller.dispose();
        // Should not throw after disposal
      });
    });
  });
}
