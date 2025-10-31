import 'package:flutter/material.dart';

/// Application configuration loaded from YAML.
class AppConfig {
  final BrandConfig brand;
  final ThemeConfig theme;
  final NetworkConfig network;
  final List<NavItemConfig> navigationItems;
  final Map<String, IconData> iconMapping;
  final FooterConfig? footer;

  const AppConfig({
    required this.brand,
    required this.theme,
    required this.network,
    required this.navigationItems,
    required this.iconMapping,
    this.footer,
  });

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      brand: BrandConfig.fromMap(map['brand'] as Map<String, dynamic>),
      theme: ThemeConfig.fromMap(map['theme'] as Map<String, dynamic>),
      network: NetworkConfig.fromMap(map['network'] as Map<String, dynamic>),
      navigationItems: (map['navigation']['items'] as List<dynamic>)
          .map((e) => NavItemConfig.fromMap(e as Map<String, dynamic>))
          .toList(),
      iconMapping: _parseIconMapping(
        map['icon_mapping'] as Map<String, dynamic>? ?? {},
      ),
      footer: map['footer'] != null
          ? FooterConfig.fromMap(map['footer'] as Map<String, dynamic>)
          : null,
    );
  }

  static Map<String, IconData> _parseIconMapping(Map<String, dynamic> mapping) {
    final result = <String, IconData>{};
    mapping.forEach((key, value) {
      final iconData = _getIconData(value as String);
      if (iconData != null) {
        result[key] = iconData;
      }
    });
    return result;
  }

  static IconData? _getIconData(String name) {
    // Map string names to Material Icons
    switch (name) {
      case 'home':
        return Icons.home;
      case 'info':
        return Icons.info;
      case 'videocam':
        return Icons.videocam;
      case 'thermostat':
        return Icons.thermostat;
      case 'security':
        return Icons.security;
      case 'settings':
        return Icons.settings;
      case 'dashboard':
        return Icons.dashboard;
      case 'devices_other':
        return Icons.devices_other;
      case 'analytics':
        return Icons.analytics;
      case 'notifications':
        return Icons.notifications;
      // Connection status icons
      case 'wifi':
        return Icons.wifi;
      case 'wifi_lock':
        return Icons.wifi_lock;
      case 'vpn_key':
        return Icons.vpn_key;
      case 'vpn_lock':
        return Icons.vpn_lock;
      case 'public':
        return Icons.public;
      default:
        return Icons.circle_outlined; // Fallback icon
    }
  }
}

class BrandConfig {
  final String name;
  final String logoLightPath;
  final String logoDarkPath;
  final String faviconPath;

  const BrandConfig({
    required this.name,
    required this.logoLightPath,
    required this.logoDarkPath,
    required this.faviconPath,
  });

  factory BrandConfig.fromMap(Map<String, dynamic> map) {
    return BrandConfig(
      name: map['name'] as String? ?? '',
      logoLightPath: map['logo_light_path'] as String? ?? '',
      logoDarkPath: map['logo_dark_path'] as String? ?? '',
      faviconPath: map['favicon_path'] as String? ?? '',
    );
  }

  String getLogoPath(bool isDarkMode) {
    return isDarkMode ? logoDarkPath : logoLightPath;
  }
}

class ThemeConfig {
  final Color seedColor;
  final Color? lightProgressColor;
  final Color? darkProgressColor;
  final Color? wifiColor;
  final Color? vpnColor;
  final Color? internetColor;

  const ThemeConfig({
    required this.seedColor,
    this.lightProgressColor,
    this.darkProgressColor,
    this.wifiColor,
    this.vpnColor,
    this.internetColor,
  });

  factory ThemeConfig.fromMap(Map<String, dynamic> map) {
    final cc = map['connection_colors'] as Map<String, dynamic>?;
    return ThemeConfig(
      seedColor: _parseColor(map['seed_color'] as String),
      lightProgressColor: map['light_progress_color'] != null
          ? _parseColor(map['light_progress_color'] as String)
          : null,
      darkProgressColor: map['dark_progress_color'] != null
          ? _parseColor(map['dark_progress_color'] as String)
          : null,
      wifiColor: cc != null && cc['wifi'] != null
          ? _parseColor(cc['wifi'] as String)
          : null,
      vpnColor: cc != null && cc['vpn'] != null
          ? _parseColor(cc['vpn'] as String)
          : null,
      internetColor: cc != null && cc['internet'] != null
          ? _parseColor(cc['internet'] as String)
          : null,
    );
  }

  static Color _parseColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}

class NetworkConfig {
  final int cacheExpirySeconds;
  final int pollingIntervalSeconds;

  const NetworkConfig({
    required this.cacheExpirySeconds,
    required this.pollingIntervalSeconds,
  });

  factory NetworkConfig.fromMap(Map<String, dynamic> map) {
    return NetworkConfig(
      cacheExpirySeconds: map['cache_expiry_seconds'] as int,
      pollingIntervalSeconds: map['polling_interval_seconds'] as int,
    );
  }

  Duration get cacheExpiry => Duration(seconds: cacheExpirySeconds);
  Duration get pollingInterval => Duration(seconds: pollingIntervalSeconds);
}

class NavItemConfig {
  final String label;
  final String? iconName;
  final String? url;
  final List<NavChildConfig> children;
  final FooterMode footerMode;

  const NavItemConfig({
    required this.label,
    this.iconName,
    this.url,
    required this.children,
    this.footerMode = FooterMode.defaultShow,
  });

  factory NavItemConfig.fromMap(Map<String, dynamic> map) {
    return NavItemConfig(
      label: map['label'] as String,
      iconName: map['icon'] as String?,
      url: map['url'] as String?,
      children: (map['children'] as List<dynamic>? ?? [])
          .map((e) => NavChildConfig.fromMap(e as Map<String, dynamic>))
          .toList(),
      footerMode: FooterModeUtils.from(map['footer']),
    );
  }

  bool get hasChildren => children.isNotEmpty;
}

class NavChildConfig {
  final String label;
  final String? url;
  final List<NavGrandchildConfig> children;
  final FooterMode footerMode;

  const NavChildConfig({
    required this.label,
    this.url,
    required this.children,
    this.footerMode = FooterMode.defaultShow,
  });

  factory NavChildConfig.fromMap(Map<String, dynamic> map) {
    return NavChildConfig(
      label: map['label'] as String,
      url: map['url'] as String?,
      children: (map['children'] as List<dynamic>? ?? [])
          .map((e) => NavGrandchildConfig.fromMap(e as Map<String, dynamic>))
          .toList(),
      footerMode: FooterModeUtils.from(map['footer']),
    );
  }

  bool get hasGrandchildren => children.isNotEmpty;
}

class NavGrandchildConfig {
  final String label;
  final String? url;
  final FooterMode footerMode;

  const NavGrandchildConfig({
    required this.label,
    this.url,
    this.footerMode = FooterMode.defaultShow,
  });

  factory NavGrandchildConfig.fromMap(Map<String, dynamic> map) {
    return NavGrandchildConfig(
      label: map['label'] as String,
      url: map['url'] as String?,
      footerMode: FooterModeUtils.from(map['footer']),
    );
  }
}

/// Footer global configuration
class FooterConfig {
  final List<FooterLink> links;
  final List<SocialLink> social;
  final List<LibraryLink> librariesUi;
  final List<LibraryLink> librariesBackend;
  final FooterAbout? about;

  const FooterConfig({
    required this.links,
    required this.social,
    required this.librariesUi,
    required this.librariesBackend,
    this.about,
  });

  factory FooterConfig.fromMap(Map<String, dynamic> map) {
    // Backward compatibility: if only `libraries` is provided, treat it as UI libs
    final legacyLibs = (map['libraries'] as List<dynamic>? ?? [])
        .map((e) => LibraryLink.fromMap(e as Map<String, dynamic>))
        .toList();
    final uiLibs = (map['libraries_ui'] as List<dynamic>? ?? [])
        .map((e) => LibraryLink.fromMap(e as Map<String, dynamic>))
        .toList();
    final beLibs = (map['libraries_backend'] as List<dynamic>? ?? [])
        .map((e) => LibraryLink.fromMap(e as Map<String, dynamic>))
        .toList();

    return FooterConfig(
      links: (map['links'] as List<dynamic>? ?? [])
          .map((e) => FooterLink.fromMap(e as Map<String, dynamic>))
          .toList(),
      social: (map['social'] as List<dynamic>? ?? [])
          .map((e) => SocialLink.fromMap(e as Map<String, dynamic>))
          .toList(),
      librariesUi: uiLibs.isNotEmpty ? uiLibs : legacyLibs,
      librariesBackend: beLibs,
      about: map['about'] != null ? FooterAbout.from(map['about']) : null,
    );
  }
}

class FooterAbout {
  final String title;
  final String text;

  const FooterAbout({required this.title, required this.text});

  factory FooterAbout.fromMap(Map<String, dynamic> map) => FooterAbout(
        title: (map['title'] as String?)?.trim().isNotEmpty == true
            ? map['title'] as String
            : 'About',
        text: (map['text'] as String?)?.trim() ?? '',
      );

  static FooterAbout from(dynamic value) {
    if (value is String) {
      return FooterAbout(title: 'About', text: value);
    }
    if (value is Map<String, dynamic>) {
      return FooterAbout.fromMap(value);
    }
    // Fallback empty about
    return const FooterAbout(title: 'About', text: '');
  }
}

class FooterLink {
  final String label;
  final String url;

  const FooterLink({required this.label, required this.url});

  factory FooterLink.fromMap(Map<String, dynamic> map) =>
      FooterLink(label: map['label'] as String, url: map['url'] as String);
}

class SocialLink {
  final String platform;
  final String url;

  const SocialLink({required this.platform, required this.url});

  factory SocialLink.fromMap(Map<String, dynamic> map) => SocialLink(
        platform: map['platform'] as String,
        url: map['url'] as String,
      );
}

class LibraryLink {
  final String name;
  final String url;

  const LibraryLink({required this.name, required this.url});

  factory LibraryLink.fromMap(Map<String, dynamic> map) => LibraryLink(
        name: map['name'] as String,
        url: map['url'] as String,
      );
}

enum FooterMode { defaultShow, none, custom }

class FooterModeUtils {
  static FooterMode from(dynamic value) {
    if (value == null) return FooterMode.defaultShow;
    if (value is bool) return value ? FooterMode.defaultShow : FooterMode.none;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'false' || v == 'none') return FooterMode.none;
      if (v == 'custom') return FooterMode.custom;
    }
    return FooterMode.defaultShow;
  }
}
