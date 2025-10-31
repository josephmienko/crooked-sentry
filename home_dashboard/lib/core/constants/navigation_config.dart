import 'package:flutter/material.dart';
import '../models/navigation_models.dart';
import '../services/config_service.dart';

/// Breakpoints for responsive layout
class Breakpoints {
  static const double mobileTiny = 600;
  static const double mobileSmall = 960;
  static const double desktop = 1535;
}

/// Navigation configuration loaded from app_config.yaml
class NavigationConfig {
  /// Get navigation items from loaded config.
  /// Must call ConfigService.load() before accessing this.
  static List<NavItem> get items {
    final config = ConfigService.config;
    return config.navigationItems.map((itemConfig) {
      // Get icon from mapping or use default
      final icon = itemConfig.iconName != null
          ? config.iconMapping[itemConfig.iconName] ?? Icons.circle_outlined
          : Icons.circle_outlined;

      final children = itemConfig.children.map((childConfig) {
        final grandchildren = childConfig.children.map((gcConfig) {
          return NavGrandchild(gcConfig.label, gcConfig.url);
        }).toList();

        return NavChild(
          childConfig.label,
          childConfig.url,
          grandchildren.isNotEmpty ? grandchildren : null,
        );
      }).toList();

      return NavItem(
        itemConfig.label,
        icon,
        children.isNotEmpty ? children : null,
      );
    }).toList();
  }
}
