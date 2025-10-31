import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/shared/widgets/theme_toggle.dart';

void main() {
  group('ThemeToggleCompact', () {
    testWidgets('should display light mode icon when theme is light', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeToggleCompact(
              themeMode: ThemeMode.light,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsNothing);
    });

    testWidgets('should display dark mode icon when theme is dark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeToggleCompact(
              themeMode: ThemeMode.dark,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      expect(find.byIcon(Icons.light_mode), findsNothing);
    });

    testWidgets('should call onToggle when tapped', (tester) async {
      var toggled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeToggleCompact(
              themeMode: ThemeMode.light,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      expect(toggled, true);
    });

    testWidgets('should have circular border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeToggleCompact(
              themeMode: ThemeMode.light,
              onToggle: () {},
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      
      expect(decoration.shape, BoxShape.circle);
      expect(container.constraints!.minWidth, 48);
      expect(container.constraints!.minHeight, 48);
    });
  });

  group('ThemeToggleFull', () {
    testWidgets('should display light mode text when theme is light', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeToggleFull(
              themeMode: ThemeMode.light,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Light mode'), findsOneWidget);
      expect(find.text('Dark mode'), findsNothing);
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('should display dark mode text when theme is dark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeToggleFull(
              themeMode: ThemeMode.dark,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Dark mode'), findsOneWidget);
      expect(find.text('Light mode'), findsNothing);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('should call onToggle when tapped', (tester) async {
      var toggled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeToggleFull(
              themeMode: ThemeMode.light,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      expect(toggled, true);
    });

    testWidgets('should have rounded shape', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemeToggleFull(
              themeMode: ThemeMode.light,
              onToggle: () {},
            ),
          ),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      final shape = listTile.shape as RoundedRectangleBorder;
      final borderRadius = shape.borderRadius as BorderRadius;
      
      expect(borderRadius.topLeft.x, 100);
    });
  });
}
