import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/core/navigation/navigation_state_manager.dart';
import '../test_helpers.dart';

void main() {
  group('NavigationStateManager', () {
    late NavigationStateManager manager;

    setUpAll(() async {
      await loadTestConfig();
    });

    setUp(() {
      manager = NavigationStateManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('initial state', () {
      test('starts with index 0', () {
        expect(manager.selectedIndex, 0);
      });

      test('starts with no child selected', () {
        expect(manager.selectedCCChild, null);
      });

      test('starts with no grandchild selected', () {
        expect(manager.selectedGrandchild, null);
      });

      test('starts with child drawer hidden', () {
        expect(manager.showChildDrawer, false);
      });

      test('starts with no expanded children', () {
        expect(manager.expandedChildren, isEmpty);
      });
    });

    // Note: Navigation methods require GoRouter context and are tested in integration tests

    group('toggleChildDrawer', () {
      test('toggles drawer visibility', () {
        expect(manager.showChildDrawer, false);
        manager.toggleChildDrawer(true);
        expect(manager.showChildDrawer, true);
        manager.toggleChildDrawer(false);
        expect(manager.showChildDrawer, false);
      });

      test('notifies listeners', () {
        var notified = false;
        manager.addListener(() {
          notified = true;
        });

        manager.toggleChildDrawer(true);
        expect(notified, true);
      });
    });

    group('closeChildDrawer', () {
      test('closes drawer', () {
        manager.toggleChildDrawer(true);
        expect(manager.showChildDrawer, true);

        manager.closeChildDrawer();
        expect(manager.showChildDrawer, false);
      });

      test('notifies listeners', () {
        manager.toggleChildDrawer(true);
        var notified = false;
        manager.addListener(() {
          notified = true;
        });

        manager.closeChildDrawer();
        expect(notified, true);
      });
    });

    group('toggleChildExpansion', () {
      test('adds index to expanded set', () {
        expect(manager.expandedChildren.contains(0), false);
        manager.toggleChildExpansion(0);
        expect(manager.expandedChildren.contains(0), true);
      });

      test('removes index if already expanded', () {
        manager.toggleChildExpansion(0);
        expect(manager.expandedChildren.contains(0), true);

        manager.toggleChildExpansion(0);
        expect(manager.expandedChildren.contains(0), false);
      });

      test('notifies listeners', () {
        var notified = false;
        manager.addListener(() {
          notified = true;
        });

        manager.toggleChildExpansion(0);
        expect(notified, true);
      });

      test('handles multiple expanded children', () {
        manager.toggleChildExpansion(0);
        manager.toggleChildExpansion(1);
        manager.toggleChildExpansion(2);

        expect(manager.expandedChildren.length, 3);
        expect(manager.expandedChildren.contains(0), true);
        expect(manager.expandedChildren.contains(1), true);
        expect(manager.expandedChildren.contains(2), true);
      });
    });
  });
}
