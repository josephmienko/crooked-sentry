import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../models/app_config.dart';

/// Service for loading and providing app configuration.
class ConfigService {
  static AppConfig? _config;

  /// Load configuration from YAML asset file.
  static Future<AppConfig> load(
      {String path = 'assets/config/app_config.yaml'}) async {
    if (_config != null) {
      return _config!;
    }

    final yamlString = await rootBundle.loadString(path);
    final yamlMap = loadYaml(yamlString) as YamlMap;

    // Convert YamlMap to regular Map for easier processing
    final map = _yamlToMap(yamlMap);

    _config = AppConfig.fromMap(map);
    return _config!;
  }

  /// Get the loaded configuration (throws if not loaded).
  static AppConfig get config {
    if (_config == null) {
      throw StateError(
          'ConfigService.load() must be called before accessing config');
    }
    return _config!;
  }

  /// Check if config has been loaded.
  static bool get isLoaded => _config != null;

  /// Clear loaded config (useful for testing).
  static void reset() {
    _config = null;
  }

  /// Recursively convert YamlMap/YamlList to Map/List.
  static dynamic _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      yaml.forEach((key, value) {
        map[key.toString()] = _yamlToMap(value);
      });
      return map;
    } else if (yaml is YamlList) {
      return yaml.map((e) => _yamlToMap(e)).toList();
    } else {
      return yaml;
    }
  }
}
