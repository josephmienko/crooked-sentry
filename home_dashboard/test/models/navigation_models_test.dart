import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_dashboard/core/models/navigation_models.dart';

void main() {
  group('NavItem', () {
    test('should create NavItem without children', () {
      const navItem = NavItem('Home', Icons.home);

      expect(navItem.label, 'Home');
      expect(navItem.icon, Icons.home);
      expect(navItem.children, null);
      expect(navItem.hasChildren, false);
    });

    test('should create NavItem with children', () {
      const navItem = NavItem('Parent', Icons.folder, [
        NavChild('Child1', 'http://example.com/1'),
        NavChild('Child2', 'http://example.com/2'),
      ]);

      expect(navItem.label, 'Parent');
      expect(navItem.hasChildren, true);
      expect(navItem.children!.length, 2);
      expect(navItem.children![0].label, 'Child1');
    });

    test('hasChildren should return false for empty children list', () {
      const navItem = NavItem('Parent', Icons.folder, []);

      expect(navItem.hasChildren, false);
    });
  });

  group('NavChild', () {
    test('should create NavChild without grandchildren', () {
      const navChild = NavChild('Live', 'http://camera.local/live');

      expect(navChild.label, 'Live');
      expect(navChild.url, 'http://camera.local/live');
      expect(navChild.grandchildren, null);
      expect(navChild.hasGrandchildren, false);
    });

    test('should create NavChild with grandchildren', () {
      const navChild = NavChild('Live', 'http://camera.local/live', [
        NavGrandchild('Driveway', 'http://camera.local/driveway'),
        NavGrandchild('Backyard', 'http://camera.local/backyard'),
      ]);

      expect(navChild.label, 'Live');
      expect(navChild.hasGrandchildren, true);
      expect(navChild.grandchildren!.length, 2);
      expect(navChild.grandchildren![0].label, 'Driveway');
    });

    test('hasGrandchildren should return false for empty grandchildren list',
        () {
      const navChild = NavChild('Live', 'http://camera.local/live', []);

      expect(navChild.hasGrandchildren, false);
    });
  });

  group('NavGrandchild', () {
    test('should create NavGrandchild', () {
      const grandchild =
          NavGrandchild('Driveway', 'http://camera.local/driveway');

      expect(grandchild.label, 'Driveway');
      expect(grandchild.url, 'http://camera.local/driveway');
    });
  });
}
