import 'package:flutter/material.dart';

/// Compact theme toggle button for NavigationRail
class ThemeToggleCompact extends StatelessWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggle;

  const ThemeToggleCompact({
    Key? key,
    required this.themeMode,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outline,
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
        onPressed: onToggle,
        tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      ),
    );
  }
}

/// Full theme toggle ListTile for drawer
class ThemeToggleFull extends StatelessWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggle;

  const ThemeToggleFull({
    Key? key,
    required this.themeMode,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
        title: Text(isDark ? 'Dark mode' : 'Light mode'),
        onTap: onToggle,
      ),
    );
  }
}
