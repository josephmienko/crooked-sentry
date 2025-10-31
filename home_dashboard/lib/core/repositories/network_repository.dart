import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_type.dart';
import '../services/network_service.dart';

/// Repository that caches and vends the client's network type.
///
/// Follows Flutter's recommended data layer pattern:
/// - Service handles HTTP calls (stateless)
/// - Repository handles caching, persistence, and business logic
class NetworkRepository {
  final NetworkService _service;
  final Duration _cacheExpiry;
  NetworkType? _cachedType;
  String? _cachedIp;
  DateTime? _lastFetch;

  static const String _storageKey = 'last_known_network_type';

  NetworkRepository({
    required NetworkService service,
    Duration cacheExpiry = const Duration(seconds: 60),
  })  : _service = service,
        _cacheExpiry = cacheExpiry;

  /// Get the current network type.
  ///
  /// Strategy:
  /// 1. If cached and fresh (< 60s old), return cached value
  /// 2. Try to fetch from server
  /// 3. On success, cache to memory + disk and return
  /// 4. On failure, return cached value if available
  /// 5. On failure with no cache, return persisted value or default to 'other'
  Future<NetworkType> getNetworkType({bool forceRefresh = false}) async {
    // Return fresh cache if available and not forcing refresh
    if (!forceRefresh && _isCacheFresh()) {
      return _cachedType!;
    }

    // Try to fetch from server
    final response = await _service.getWhoAmI();
    if (response != null) {
      _cachedType = NetworkType.fromString(response.network);
      _cachedIp = response.ip;
      _lastFetch = DateTime.now();

      // Persist to disk for offline resilience
      await _persistNetworkType(_cachedType!);

      return _cachedType!;
    }

    // Fetch failed - return cached value if we have one
    if (_cachedType != null) {
      return _cachedType!;
    }

    // No cache and fetch failed - load from disk or default to 'other'
    _cachedType = await _loadPersistedNetworkType() ?? NetworkType.other;
    return _cachedType!;
  }

  /// Get the cached client IP address, if available.
  String? get clientIp => _cachedIp;

  /// Clear the in-memory cache (disk cache remains for offline use).
  void invalidate() {
    _cachedType = null;
    _cachedIp = null;
    _lastFetch = null;
  }

  /// Check if we have a cached value without triggering a fetch.
  bool get hasCached => _cachedType != null;

  /// Get the cached network type without fetching (returns null if not cached).
  NetworkType? get cachedNetworkType => _cachedType;

  /// Check if the cache is still fresh (< 60 seconds old).
  bool _isCacheFresh() {
    if (_cachedType == null || _lastFetch == null) {
      return false;
    }
    return DateTime.now().difference(_lastFetch!) < _cacheExpiry;
  }

  /// Persist network type to disk for offline use.
  Future<void> _persistNetworkType(NetworkType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, type.name);
    } catch (_) {
      // Silently fail - persistence is a nice-to-have, not critical
    }
  }

  /// Load the last known network type from disk.
  Future<NetworkType?> _loadPersistedNetworkType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_storageKey);
      if (value != null) {
        return NetworkType.values.firstWhere(
          (e) => e.name == value,
          orElse: () => NetworkType.other,
        );
      }
    } catch (_) {
      // Silently fail
    }
    return null;
  }
}
