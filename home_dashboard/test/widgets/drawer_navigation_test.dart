import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/core/models/navigation_models.dart';
import 'package:home_dashboard/shared/navigation/drawer_navigation.dart';

void main() {
  group('DrawerNavigation', () {
    final testNavItems = [
      const NavItem('Home', Icons.home),
      const NavItem('About', Icons.info),
      const NavItem('Settings', Icons.settings, [
        NavChild('Profile', 'http://example.com/profile'),
        NavChild('Preferences', 'http://example.com/preferences'),
      ]),
    ];

    testWidgets('should display all navigation items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawerNavigation(
              navItems: testNavItems,
              selectedIndex: 0,
              themeMode: ThemeMode.light,
              onNavTap: (_) {},
              onThemeToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should show arrow for items with children', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawerNavigation(
              navItems: testNavItems,
              selectedIndex: 0,
              themeMode: ThemeMode.light,
              onNavTap: (_) {},
              onThemeToggle: () {},
            ),
          ),
        ),
      );

      // Settings has children, so it should have an arrow
      final settingsTile = find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(ListTile),
      );
      
      expect(settingsTile, findsOneWidget);
      
      // Home doesn't have children, so no arrow
      final homeTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Home'),
          matching: find.byType(ListTile),
        ),
      );
      expect(homeTile.trailing, null);
    });

    testWidgets('should highlight selected item', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawerNavigation(
              navItems: testNavItems,
              selectedIndex: 1,
              themeMode: ThemeMode.light,
              onNavTap: (_) {},
              onThemeToggle: () {},
            ),
          ),
        ),
      );

      final aboutTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('About'),
          matching: find.byType(ListTile),
        ),
      );
      
      expect(aboutTile.selected, true);
    });

    testWidgets('should call onNavTap when item is tapped', (tester) async {
      int? tappedIndex;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawerNavigation(
              navItems: testNavItems,
              selectedIndex: 0,
              themeMode: ThemeMode.light,
              onNavTap: (index) => tappedIndex = index,
              onThemeToggle: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('About'));
      expect(tappedIndex, 1);
    });

    testWidgets('should display theme toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawerNavigation(
              navItems: testNavItems,
              selectedIndex: 0,
              themeMode: ThemeMode.light,
              onNavTap: (_) {},
              onThemeToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Light mode'), findsOneWidget);
    });

    testWidgets('should call onThemeToggle when theme toggle is tapped', (tester) async {
      var toggled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawerNavigation(
              navItems: testNavItems,
              selectedIndex: 0,
              themeMode: ThemeMode.light,
              onNavTap: (_) {},
              onThemeToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Light mode'));
      expect(toggled, true);
    });
  });
}
