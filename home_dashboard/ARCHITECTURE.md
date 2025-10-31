# Architecture

## Overview

This Flutter application follows a **Hybrid (Feature-First + Layered)** architecture pattern, combining the benefits of:
- **Feature-First**: Features are self-contained modules in `lib/features/`
- **Layered**: Shared infrastructure is organized by technical concerns in `lib/core/` and `lib/shared/`

## Directory Structure

```
lib/
├── core/                       # Core infrastructure (app-wide)
│   ├── constants/             # App-wide constants and configuration
│   │   └── navigation_config.dart
│   ├── models/                # Core data models
│   │   ├── app_config.dart
│   │   ├── navigation_models.dart
│   │   └── network_type.dart
│   ├── repositories/          # Data layer (caching, persistence)
│   │   └── network_repository.dart
│   └── services/              # Business logic services
│       ├── animation_service.dart
│       ├── config_service.dart
│       └── network_service.dart
│
├── shared/                     # Shared UI components and utilities
│   ├── navigation/            # Navigation widgets
│   │   ├── child_drawer.dart
│   │   ├── drawer_navigation.dart
│   │   └── rail_navigation.dart
│   └── widgets/               # Reusable widgets
│       ├── animation_toggle.dart
│       ├── footer_widget.dart
│       ├── looping_video_card.dart
│       └── theme_toggle.dart
│
├── features/                   # Feature modules
│   ├── home/                  # Home feature
│   │   ├── home_page.dart
│   │   └── widgets/           # Home-specific widgets
│   │       └── welcome_card.dart
│   ├── video/                 # Video feature
│   │   └── video_page.dart
│   └── welcome/               # Welcome/About feature
│       └── welcome_page.dart
│
├── main.dart                   # App entry point
├── router.dart                 # go_router configuration
└── responsive_scaffold.dart    # Main app scaffold
```

## Layer Responsibilities

### Core Layer
**Purpose**: Application-wide infrastructure that's independent of UI

- **constants/**: Configuration values, navigation structure
- **models/**: Data models used across the app
- **repositories/**: Data access, caching, and persistence logic
- **services/**: Business logic and external service integrations

### Shared Layer
**Purpose**: Reusable UI components and utilities

- **navigation/**: Navigation drawer, rail, and related widgets
- **widgets/**: Reusable UI components (buttons, cards, toggles)

### Features Layer
**Purpose**: Self-contained feature modules

Each feature can have:
- Page(s): Top-level route(s)
- widgets/: Feature-specific widgets
- (Future) data/, domain/, presentation/ as features grow

### Root Level
- `main.dart`: App initialization, theme configuration, network polling
- `router.dart`: Route configuration using go_router
- `responsive_scaffold.dart`: Main scaffold with responsive AppBar, navigation, and footer

## Import Conventions

### From core to core
```dart
import '../models/app_config.dart';
import '../services/network_service.dart';
```

### From shared to core
```dart
import '../../core/models/navigation_models.dart';
import '../../core/services/animation_service.dart';
```

### From features to core or shared
```dart
// Core import
import '../../core/services/config_service.dart';

// Shared import
import '../../shared/widgets/looping_video_card.dart';

// Feature-local import
import 'widgets/welcome_card.dart';
```

### From root to core, shared, or features
```dart
import 'core/models/network_type.dart';
import 'shared/navigation/drawer_navigation.dart';
import 'features/home/home_page.dart';
```

## Key Architectural Decisions

### 1. Feature Isolation
- Each feature in `lib/features/` is self-contained
- Feature-specific widgets live in `features/{feature}/widgets/`
- Features communicate via core services and models

### 2. Shared Components
- Truly reusable widgets (footer, video player, toggles) live in `shared/widgets/`
- Navigation components (drawer, rail) live in `shared/navigation/`

### 3. Core Infrastructure
- Services are singletons or stateless (NetworkService, ConfigService, AnimationService)
- Repositories handle caching and data transformation
- Models are immutable data classes

### 4. Responsive Design
- `ResponsiveScaffold` manages layout breakpoints:
  - `<600px`: Tiny mobile (drawer)
  - `600-960px`: Small mobile/tablet (drawer)
  - `≥960px`: Desktop (rail navigation)

### 5. State Management
- ThemeMode: Passed down from `main.dart` via router to scaffold
- Animation state: Global `AnimationService` with `ValueNotifier<bool>`
- Network state: Polled in `main.dart`, passed via router to scaffold

## Testing Structure

Tests mirror the lib structure:
```
test/
├── models/                    # Core model tests
├── repositories/              # Repository tests
├── services/                  # Service tests
├── widgets/                   # Widget tests
└── test_helpers.dart          # Test utilities
```

## Future Enhancements

As features grow, consider:
- Adding `data/`, `domain/`, `presentation/` subdirectories within features (Clean Architecture)
- Moving to a state management solution (Riverpod, Bloc) if state complexity increases
- Creating a `lib/core/theme/` directory for theme-related constants
- Adding `lib/core/utils/` for pure utility functions

## References

- [Flutter Architecture Samples](https://github.com/brianegan/flutter_architecture_samples)
- [Very Good Ventures Flutter Style Guide](https://verygood.ventures/blog/very-good-flutter-architecture)
- [Riverpod Architecture Guide](https://codewithandrea.com/articles/flutter-app-architecture-riverpod-introduction/)
