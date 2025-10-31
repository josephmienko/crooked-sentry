import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/shared/widgets/responsive_app_bar.dart';
import 'package:home_dashboard/core/models/network_type.dart';
import 'package:home_dashboard/core/services/config_service.dart';
import '../test_helpers.dart';

void main() {
  group('ResponsiveAppBar', () {
    setUpAll(() async {
      await loadTestConfig();
    });

    testWidgets('renders with default state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: ResponsiveAppBar(
              isScrolled: false,
              networkType: NetworkType.wifi,
              networkLoaded: false,
            ),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('changes background color when scrolled', (tester) async {
      // Not scrolled
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            appBar: ResponsiveAppBar(
              isScrolled: false,
              networkType: NetworkType.wifi,
              networkLoaded: false,
            ),
          ),
        ),
      );

      final AppBar notScrolledAppBar = tester.widget(find.byType(AppBar).first);
      final notScrolledColor = notScrolledAppBar.backgroundColor;

      // Scrolled
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            appBar: ResponsiveAppBar(
              isScrolled: true,
              networkType: NetworkType.wifi,
              networkLoaded: false,
            ),
          ),
        ),
      );

      final AppBar scrolledAppBar = tester.widget(find.byType(AppBar).first);
      final scrolledColor = scrolledAppBar.backgroundColor;

      expect(scrolledColor, isNot(equals(notScrolledColor)));
    });

    group('brand title', () {
      testWidgets('displays brand name when configured', (tester) async {
        final config = ConfigService.config;
        final brandName = config.brand.name;

        if (brandName.isNotEmpty) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                appBar: ResponsiveAppBar(
                  isScrolled: false,
                  networkType: NetworkType.wifi,
                  networkLoaded: false,
                ),
              ),
            ),
          );

          expect(find.text(brandName), findsOneWidget);
        }
      });

      testWidgets('calls onBrandTap when tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: ResponsiveAppBar(
                isScrolled: false,
                networkType: NetworkType.wifi,
                networkLoaded: false,
                onBrandTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        );

        final config = ConfigService.config;
        if (config.brand.name.isNotEmpty) {
          await tester.tap(find.text(config.brand.name));
          await tester.pump();
          expect(tapped, true);
        }
      });
    });

    group('network indicator', () {
      testWidgets('shows network indicator when networkLoaded is true',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: ResponsiveAppBar(
                isScrolled: false,
                networkType: NetworkType.wifi,
                networkLoaded: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.vpn_key), findsOneWidget);
      });

      testWidgets('hides network indicator when networkLoaded is false',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: ResponsiveAppBar(
                isScrolled: false,
                networkType: NetworkType.wifi,
                networkLoaded: false,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.vpn_key), findsNothing);
        expect(find.byIcon(Icons.vpn_key_off), findsNothing);
      });

      testWidgets('shows vpn_key icon for secure networks', (tester) async {
        // WiFi
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: ResponsiveAppBar(
                isScrolled: false,
                networkType: NetworkType.wifi,
                networkLoaded: true,
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.vpn_key), findsOneWidget);

        // VPN
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: ResponsiveAppBar(
                isScrolled: false,
                networkType: NetworkType.vpn,
                networkLoaded: true,
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.vpn_key), findsOneWidget);
      });

      testWidgets('shows vpn_key_off icon for other/internet', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: ResponsiveAppBar(
                isScrolled: false,
                networkType: NetworkType.other,
                networkLoaded: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.vpn_key_off), findsOneWidget);
      });

      testWidgets('calls onRefreshNetwork when tapped', (tester) async {
        var refreshCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: ResponsiveAppBar(
                isScrolled: false,
                networkType: NetworkType.wifi,
                networkLoaded: true,
                onRefreshNetwork: () {
                  refreshCalled = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.vpn_key));
        await tester.pump();
        expect(refreshCalled, true);
      });

      testWidgets('shows tooltip with network type and refresh hint',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: ResponsiveAppBar(
                isScrolled: false,
                networkType: NetworkType.wifi,
                networkLoaded: true,
              ),
            ),
          ),
        );

        final tooltip = find.byType(Tooltip).last;
        expect(tooltip, findsOneWidget);

        final tooltipWidget = tester.widget<Tooltip>(tooltip);
        expect(tooltipWidget.message, contains('WiFi'));
        expect(tooltipWidget.message, contains('refresh'));
      });
    });

    testWidgets('has correct preferred size', (tester) async {
      final appBar = ResponsiveAppBar(
        isScrolled: false,
        networkType: NetworkType.wifi,
        networkLoaded: false,
      );

      expect(appBar.preferredSize, const Size.fromHeight(64));
    });

    testWidgets('menu button opens drawer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: ResponsiveAppBar(
              isScrolled: false,
              networkType: NetworkType.wifi,
              networkLoaded: false,
            ),
            drawer: const Drawer(
              child: Text('Drawer'),
            ),
          ),
        ),
      );

      // Tap menu button
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Drawer should be open
      expect(find.text('Drawer'), findsOneWidget);
    });
  });
}
