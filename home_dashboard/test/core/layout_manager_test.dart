import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/core/layout/layout_manager.dart';
import 'package:home_dashboard/core/constants/navigation_config.dart';

void main() {
  group('LayoutManager', () {
    late LayoutManager layoutManager;

    setUp(() {
      layoutManager = LayoutManager();
    });

    tearDown(() {
      layoutManager.dispose();
    });

    group('modeFromWidth', () {
      test('returns tiny mode for widths < 600', () {
        expect(LayoutManager.modeFromWidth(0), LayoutMode.tiny);
        expect(LayoutManager.modeFromWidth(599), LayoutMode.tiny);
      });

      test('returns small mode for widths 600-959', () {
        expect(LayoutManager.modeFromWidth(600), LayoutMode.small);
        expect(LayoutManager.modeFromWidth(800), LayoutMode.small);
        expect(LayoutManager.modeFromWidth(959), LayoutMode.small);
      });

      test('returns medium mode for widths 960-1534', () {
        expect(LayoutManager.modeFromWidth(960), LayoutMode.medium);
        expect(LayoutManager.modeFromWidth(1200), LayoutMode.medium);
        expect(LayoutManager.modeFromWidth(1534), LayoutMode.medium);
      });

      test('returns desktop mode for widths >= 1535', () {
        expect(LayoutManager.modeFromWidth(1535), LayoutMode.desktop);
        expect(LayoutManager.modeFromWidth(1920), LayoutMode.desktop);
        expect(LayoutManager.modeFromWidth(3840), LayoutMode.desktop);
      });
    });

    group('updateLayout', () {
      test('updates last width', () {
        layoutManager.updateLayout(1024);
        expect(layoutManager.lastWidth, 1024);
      });

      test('updates current mode', () {
        layoutManager.updateLayout(1024);
        expect(layoutManager.currentMode, LayoutMode.medium);
      });

      test('returns true when mode changes', () {
        layoutManager.updateLayout(500); // tiny
        final changed = layoutManager.updateLayout(1024); // medium
        expect(changed, true);
      });

      test('returns false when mode stays the same', () {
        layoutManager.updateLayout(1000); // medium
        final changed = layoutManager.updateLayout(1200); // still medium
        expect(changed, false);
      });

      test('notifies listeners when mode changes', () {
        var notified = false;
        layoutManager.addListener(() {
          notified = true;
        });

        layoutManager.updateLayout(500); // tiny
        notified = false;
        layoutManager.updateLayout(1024); // medium - should notify
        expect(notified, true);
      });

      test('does not notify listeners when mode stays the same', () {
        layoutManager.updateLayout(1000); // medium
        var notified = false;
        layoutManager.addListener(() {
          notified = true;
        });

        layoutManager.updateLayout(1200); // still medium - should not notify
        expect(notified, false);
      });
    });

    group('shouldCloseDrawersOnExpand', () {
      test('returns true when expanding from tiny to small', () {
        final result = layoutManager.shouldCloseDrawersOnExpand(
          599, // < mobileSmall
          960, // >= mobileSmall
        );
        expect(result, true);
      });

      test('returns true when expanding from medium to desktop', () {
        final result = layoutManager.shouldCloseDrawersOnExpand(
          1534, // < desktop
          1535, // >= desktop
        );
        expect(result, true);
      });

      test('returns false when not crossing breakpoints', () {
        final result = layoutManager.shouldCloseDrawersOnExpand(
          1000, // medium
          1200, // still medium
        );
        expect(result, false);
      });

      test('returns false when shrinking', () {
        final result = layoutManager.shouldCloseDrawersOnExpand(
          1535, // desktop
          1200, // medium
        );
        expect(result, false);
      });
    });

    group('shouldCloseChildDrawerOnShrink', () {
      test('returns true when shrinking from desktop to medium', () {
        final result = layoutManager.shouldCloseChildDrawerOnShrink(
          1535, // >= desktop
          1534, // < desktop
        );
        expect(result, true);
      });

      test('returns false when not crossing desktop breakpoint', () {
        final result = layoutManager.shouldCloseChildDrawerOnShrink(
          1200, // medium
          1000, // still not desktop
        );
        expect(result, false);
      });

      test('returns false when expanding', () {
        final result = layoutManager.shouldCloseChildDrawerOnShrink(
          1200, // < desktop
          1600, // >= desktop
        );
        expect(result, false);
      });
    });

    test('Breakpoints constants match expected values', () {
      expect(Breakpoints.mobileTiny, 600);
      expect(Breakpoints.mobileSmall, 960);
      expect(Breakpoints.desktop, 1535);
    });
  });
}
