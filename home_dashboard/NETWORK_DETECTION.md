# Network Detection Architecture

## Overview

The app detects whether users are accessing from **Local WiFi**, **VPN**, or **Internet** using server-side classification and Flutter's recommended data layer pattern.

## How It Works

### Server Side (Nginx)

The Nginx reverse proxy classifies clients by IP address using geo/map directives:

- **LAN**: Clients in configured LAN CIDRs (e.g., 192.168.0.0/24, 172.16.0.0/12)
- **VPN**: Clients in WireGuard CIDRs (e.g., 10.8.0.0/24)
- **Internet**: All other clients

Configuration: `ansible/roles/nginx/templates/site.conf.j2`

### API Endpoint

**GET /whoami** returns JSON:
```json
{
  "network": "lan|vpn|internet",
  "ip": "192.168.1.100"
}
```

Also exposes headers:
- `X-Client-Network`: lan | vpn | internet
- `X-Client-IP`: observed client IP

### Client Side (Flutter)

Follows Flutter's data layer pattern with smart caching and persistence:

```
NetworkService (stateless HTTP) → NetworkRepository (cache + persistence) → App State
```

#### Caching Strategy

The repository implements a multi-layer caching approach:

1. **In-memory cache** (60-second expiry)
   - Fast access for repeated checks
   - Auto-refreshes after 60 seconds

2. **Persistent storage** (SharedPreferences)
   - Survives app restarts
   - Critical for offline resilience
   - Falls back to last known network type if server unreachable

3. **Automatic polling** (every 60 seconds)
   - Detects network changes while app is running
   - WiFi → VPN, VPN → Internet transitions

4. **Lifecycle-aware refresh**
   - App resume from background triggers immediate refresh
   - Ensures current state after device reconnects

5. **Manual refresh**
   - Tap network indicator icon to force immediate check
   - Bypasses cache, fetches fresh from server

#### Files

- **lib/models/network_type.dart**: NetworkType enum (wifi/vpn/other)
- **lib/services/network_service.dart**: HTTP client for /whoami
- **lib/repositories/network_repository.dart**: Caches and vends network type
- **lib/main.dart**: Fetches on app start, passes to ResponsiveScaffold
- **lib/responsive_scaffold.dart**: Shows network indicator in AppBar

#### Usage Example

```dart
// Access from app state
final networkType = widget.networkType;

if (networkType == NetworkType.wifi) {
  // Show LAN-only features
} else if (networkType == NetworkType.vpn) {
  // Show VPN features
} else {
  // Internet - limited access
}
```

## Testing

35 unit tests covering:

- NetworkType enum parsing and labels
- NetworkService HTTP success/failure cases
- NetworkRepository caching, expiry, and persistence
- Fallback to persisted value when offline

Run: `flutter test`

## Deployment

1. Update Nginx config via Ansible:

   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.ini site.yml --tags nginx
   ```

2. Reload Nginx on the Pi:

   ```bash
   sudo systemctl reload nginx
   ```

3. Deploy Flutter app (web/mobile/desktop)

## Notes

- **Cross-platform**: Works on web, mobile, and desktop—server determines network type
- **Security**: Don't trust client-side network detection for access control; use Nginx geo blocking
- **Offline resilience**: Last known network type persisted to disk; if server unreachable, falls back to cached value
- **Polling interval**: 60 seconds for automatic checks; adjust `_pollInterval` in `main.dart` if needed
- **Manual refresh**: Tap the network indicator icon in the AppBar to force immediate refresh
- **Cache expiry**: In-memory cache refreshes every 60 seconds; change `_cacheExpiry` in `network_repository.dart` if needed
- **IPv6**: Add ULA ranges (fc00::/7) and WireGuard v6 subnet to Nginx geo blocks if needed
- **CDN/Proxy**: Configure real client IP handling in Nginx if behind Cloudflare/load balancer

## Why Persistence Matters

Scenario: User is on local WiFi → WiFi drops briefly → still on same LAN

- **Without persistence**: App defaults to "other" (Internet), hides local features
- **With persistence**: App remembers "last known: WiFi", keeps features accessible until confirmed otherwise

This prevents jarring UX when connectivity hiccups but user is still physically local.
