import 'dart:async';
import 'package:flutter/material.dart';
import 'core/repositories/network_repository.dart';
import 'core/services/network_service.dart';
import 'core/services/config_service.dart';
import 'core/models/network_type.dart';
import 'core/models/app_config.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load app configuration before running app
  await ConfigService.load();

  runApp(const CrookedSentryApp());
}

class CrookedSentryApp extends StatefulWidget {
  const CrookedSentryApp({super.key});

  @override
  State<CrookedSentryApp> createState() => _CrookedSentryAppState();
}

class _CrookedSentryAppState extends State<CrookedSentryApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  late final NetworkRepository _networkRepository;
  late final AppConfig _config;
  NetworkType _networkType = NetworkType.other;
  bool _networkLoaded = false;
  Timer? _pollTimer;

  // DEBUG: Override network type for local testing via compile-time env var
  // Usage: flutter run --dart-define=DEBUG_NETWORK=wifi
  // Values: 'wifi', 'vpn', 'internet', or unset for real detection
  static NetworkType? get _debugNetworkOverride {
    const debugValue = String.fromEnvironment('DEBUG_NETWORK');
    if (debugValue.isEmpty) return null;
    switch (debugValue.toLowerCase()) {
      case 'wifi':
      case 'lan':
        return NetworkType.wifi;
      case 'vpn':
        return NetworkType.vpn;
      case 'internet':
      case 'other':
        return NetworkType.other;
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _config = ConfigService.config;
    WidgetsBinding.instance.addObserver(this);
    _networkRepository = NetworkRepository(
      service: NetworkService(),
      cacheExpiry: _config.network.cacheExpiry,
    );
    _loadNetworkType();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back from background - refresh network status
      _refreshNetworkType();
    }
  }

  /// Initial load - uses cached/persisted value if available
  Future<void> _loadNetworkType() async {
    // Use debug override if set, otherwise fetch from repository
    final type =
        _debugNetworkOverride ?? await _networkRepository.getNetworkType();
    if (mounted) {
      setState(() {
        _networkType = type;
        _networkLoaded = true;
      });
    }
  }

  /// Force refresh - ignores cache and fetches from server
  Future<void> _refreshNetworkType() async {
    // Use debug override if set, otherwise fetch from repository
    final type = _debugNetworkOverride ??
        await _networkRepository.getNetworkType(forceRefresh: true);
    if (mounted) {
      setState(() {
        _networkType = type;
        _networkLoaded = true;
      });
    }
  }

  /// Start periodic polling to detect network changes
  void _startPolling() {
    _pollTimer = Timer.periodic(_config.network.pollingInterval, (_) {
      _loadNetworkType(); // Uses smart caching (60s expiry)
    });
  }

  /// Stop periodic polling
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void refreshNetwork() {
    _refreshNetworkType();
  }

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(
      themeMode: _themeMode,
      onThemeModeChanged: setThemeMode,
      networkType: _networkType,
      networkLoaded: _networkLoaded,
      onRefreshNetwork: refreshNetwork,
    );

    return MaterialApp.router(
      title: _config.brand.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _config.theme.seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: _config.theme.lightProgressColor ?? _config.theme.seedColor,
          linearTrackColor: const Color(0xFFE0E0E0),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _config.theme.seedColor,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _config.theme.seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: _config.theme.darkProgressColor ?? const Color(0xFF4CAF50),
          linearTrackColor: const Color(0xFF2C2C2C),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _config.theme.seedColor,
        ),
      ),
      themeMode: _themeMode,
      routerConfig: router,
    );
  }
}
