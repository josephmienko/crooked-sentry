# App Configuration Guide

The Crooked Sentry Home Dashboard uses a YAML-based configuration system to keep all customizable values in one place, making it easy to rebrand, adjust behavior, and maintain the app.

## Configuration File Location

```
assets/config/app_config.yaml
```

## What's Configurable?

### 1. Brand Identity

```yaml
brand:
  name: "Crooked Sentry"
  logo_path: "assets/icons/CC_logo.png"
  favicon_path: "favicon.png"
```

- **name**: App title shown in AppBar and browser tab
- **logo_path**: Path to your brand logo (must be declared in pubspec.yaml assets)
- **favicon_path**: Favicon for web builds

### 2. Theme Colors

```yaml
theme:
  seed_color: "#191d16"
  light_progress_color: "#191d16"
  dark_progress_color: "#4CAF50"
```

- **seed_color**: Material 3 seed color (generates full color scheme)
- **light_progress_color**: Progress indicators in light mode (optional, defaults to seed_color)
- **dark_progress_color**: Progress indicators in dark mode (optional, defaults to #4CAF50)

### 3. Network Detection Settings

```yaml
network:
  cache_expiry_seconds: 60
  polling_interval_seconds: 60
```

- **cache_expiry_seconds**: How long to cache network type in memory before re-checking
- **polling_interval_seconds**: How often to poll server for network changes while app is running

### 4. Navigation Structure

Define your entire navigation hierarchy with icons, labels, and URLs:

```yaml
navigation:
  items:
    - label: "Home"
      icon: "home"
      url: null
      children: []

    - label: "CC-CC-TV"
      icon: "videocam"
      url: null
      children:
        - label: "Live"
          url: "/frigate/live"
          children:
            - label: "Driveway"
              url: "/frigate/live/driveway"
            - label: "Backyard"
              url: "/frigate/live/backyard"
```

**Structure:**
- Top-level items appear in drawer/rail
- Children appear in expandable sections
- Grandchildren appear nested under children
- URLs can be `null` for items with children or actual endpoints

### 5. Icon Mapping

Map string names to Material Icons:

```yaml
icon_mapping:
  home: "home"
  info: "info"
  videocam: "videocam"
  thermostat: "thermostat"
  # Add more icons as needed
```

**Available icons:** See [Material Icons](https://fonts.google.com/icons?icon.set=Material+Icons)

**Supported icons in code:**
- home, info, videocam, thermostat, security, settings, dashboard
- devices_other, analytics, notifications
- Falls back to `circle_outlined` if not found

To add new icons, update the `_getIconData()` method in `lib/models/app_config.dart`.

## How It Works

### 1. Config Loading

The app loads configuration at startup in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.load();
  runApp(const CrookedSentryApp());
}
```

### 2. Accessing Config

Anywhere in the app:

```dart
import 'package:home_dashboard/services/config_service.dart';

// Get config values
final brandName = ConfigService.config.brand.name;
final logoPath = ConfigService.config.brand.logoPath;
final seedColor = ConfigService.config.theme.seedColor;
```

### 3. Config Models

- **AppConfig**: Top-level container
- **BrandConfig**: Brand identity (name, logo, favicon)
- **ThemeConfig**: Colors (seed, progress indicators)
- **NetworkConfig**: Cache and polling intervals
- **NavItemConfig / NavChildConfig / NavGrandchildConfig**: Navigation hierarchy

## Making Changes

### To Change Brand Name or Logo

1. Edit `assets/config/app_config.yaml`:
   ```yaml
   brand:
     name: "My New App Name"
     logo_path: "assets/icons/new_logo.png"
   ```

2. If using a new logo, add it to pubspec.yaml:
   ```yaml
   flutter:
     assets:
       - assets/icons/new_logo.png
       - assets/config/app_config.yaml
   ```

3. Hot restart the app (R in terminal)

### To Change Theme Colors

1. Edit `app_config.yaml`:
   ```yaml
   theme:
     seed_color: "#0000FF"  # Blue instead of green
   ```

2. Hot restart (R)

### To Add Navigation Items

1. Edit `app_config.yaml` navigation section
2. Add icon mapping if using new icon:
   ```yaml
   icon_mapping:
     my_new_icon: "star"  # Material icon name
   ```

3. If icon isn't in supported list, add to `lib/models/app_config.dart`:
   ```dart
   case 'star':
     return Icons.star;
   ```

4. Hot restart (R)

### To Adjust Network Polling

1. Edit `app_config.yaml`:
   ```yaml
   network:
     cache_expiry_seconds: 30  # Faster refresh
     polling_interval_seconds: 30
   ```

2. Hot restart (R)

## Testing

Tests automatically load config via `test_helpers.dart`:

```dart
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await loadTestConfig();
  });
  
  // Your tests...
}
```

## Benefits

✅ **Single source of truth** - all customizable values in one YAML file  
✅ **No code changes** - rebrand without touching Dart code  
✅ **Type-safe** - parsed into strongly-typed Dart models  
✅ **Hot-reload friendly** - restart to see changes (no full rebuild)  
✅ **Easy deployment** - swap config file for different environments  
✅ **Testable** - mock configs for unit tests  

## Advanced: Multiple Environments

You could maintain separate configs:

```
assets/config/
  app_config.yaml          # Default
  app_config.dev.yaml      # Development
  app_config.prod.yaml     # Production
```

Then load based on environment:

```dart
final configPath = kDebugMode
    ? 'assets/config/app_config.dev.yaml'
    : 'assets/config/app_config.yaml';
    
await ConfigService.load(path: configPath);
```

## Files Reference

- **Config definition**: `assets/config/app_config.yaml`
- **Config models**: `lib/models/app_config.dart`
- **Config service**: `lib/services/config_service.dart`
- **Usage in main**: `lib/main.dart`
- **Usage in navigation**: `lib/constants/navigation_config.dart`
- **Test helpers**: `test/test_helpers.dart`
