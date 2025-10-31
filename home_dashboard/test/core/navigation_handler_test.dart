import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/core/navigation/navigation_handler.dart';
import 'package:home_dashboard/core/navigation/navigation_state_manager.dart';
import 'package:home_dashboard/shared/widgets/footer_controller.dart';
import '../test_helpers.dart';

void main() {
  group('NavigationHandler', () {
    late NavigationHandler handler;
    late NavigationStateManager stateManager;
    late FooterController footerController;

    setUpAll(() async {
      await loadTestConfig();
    });

    setUp(() {
      stateManager = NavigationStateManager();
      footerController = FooterController();
      handler = NavigationHandler(
        stateManager: stateManager,
        footerController: footerController,
      );
    });

    tearDown(() {
      stateManager.dispose();
      footerController.dispose();
    });

    test('initializes with default navigation items', () {
      expect(handler.navItems, isNotEmpty);
    });

    test('can be initialized with custom nav items', () {
      final customHandler = NavigationHandler(
        stateManager: stateManager,
        footerController: footerController,
        navItems: [],
      );
      expect(customHandler.navItems, isEmpty);
    });

    test('shouldShowChildMenu returns true for items with children', () {
      // Assuming index 2 has children (Command Center)
      expect(handler.shouldShowChildMenu(2), isTrue);
    });

    test('shouldShowChildMenu returns false for items without children', () {
      // Assuming index 0 has no children (Home)
      expect(handler.shouldShowChildMenu(0), isFalse);
    });

    // Note: Navigation callback tests require BuildContext and are tested in integration tests
  });
}
