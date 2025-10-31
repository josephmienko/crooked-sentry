import 'package:flutter/material.dart';

/// Represents a top-level navigation item
class NavItem {
  final String label;
  final IconData icon;
  final List<NavChild>? children;

  const NavItem(this.label, this.icon, [this.children]);

  bool get hasChildren => children != null && children!.isNotEmpty;
}

/// Represents a second-level navigation item (child of NavItem)
class NavChild {
  final String label;
  final String? url;
  final List<NavGrandchild>? grandchildren;

  const NavChild(this.label, this.url, [this.grandchildren]);

  bool get hasGrandchildren =>
      grandchildren != null && grandchildren!.isNotEmpty;
}

/// Represents a third-level navigation item (grandchild of NavItem)
class NavGrandchild {
  final String label;
  final String? url;

  const NavGrandchild(this.label, this.url);
}
