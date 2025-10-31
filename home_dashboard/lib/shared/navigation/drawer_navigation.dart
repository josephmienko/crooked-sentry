import 'package:flutter/material.dart';
import '../../core/models/navigation_models.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/animation_toggle.dart';

/// Main navigation drawer for small screens
class DrawerNavigation extends StatelessWidget {
  final List<NavItem> navItems;
  final int selectedIndex;
  final ThemeMode themeMode;
  final Function(int) onNavTap;
  final VoidCallback onThemeToggle;

  const DrawerNavigation({
    Key? key,
    required this.navItems,
    required this.selectedIndex,
    required this.themeMode,
    required this.onNavTap,
    required this.onThemeToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (int i = 0; i < navItems.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                selected: selectedIndex == i,
                selectedTileColor: colorScheme.secondaryContainer,
                leading: Icon(navItems[i].icon),
                title: Text(navItems[i].label),
                trailing: navItems[i].hasChildren
                    ? const Icon(Icons.arrow_right)
                    : null,
                onTap: () => onNavTap(i),
              ),
            ),
          const Divider(),
          const AnimationToggleFull(),
          const SizedBox(height: 12),
          ThemeToggleFull(
            themeMode: themeMode,
            onToggle: onThemeToggle,
          ),
        ],
      ),
    );
  }
}
