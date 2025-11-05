# iOS Native App Handoff Document

## Project Overview

**crooked-services** is a home automation infrastructure built on a Raspberry Pi 4 that serves:
- **Frigate NVR** (security camera monitoring)
- **Home Assistant** (smart home hub with climate control, TV remote, etc.)
- **WireGuard VPN** (secure remote access)

The current Flutter web app (`home_dashboard/`) successfully proves the concept but needs to become a native iOS app with **embedded WireGuard VPN** to simplify end-user experience.

---

## Current Architecture

### Backend Services (Raspberry Pi @ 192.168.0.200)

```
┌─────────────────────────────────────────────┐
│    Raspberry Pi (192.168.0.200)             │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ Nginx Reverse Proxy (Port 80)       │   │
│  │ - Network-aware access control      │   │
│  │ - CORS enabled for all endpoints    │   │
│  │ - Auto-injects HA auth token        │   │
│  └─────────────────────────────────────┘   │
│           │                                 │
│  ┌────────┴────────────────────────────┐   │
│  │                                      │   │
│  │  /frigate/ → Frigate:5000           │   │
│  │  /homeassistant/ → HA:8123          │   │
│  │  /climate/ → HA:8123                │   │
│  │  /whoami → Network detection         │   │
│  │  /household.conf → WireGuard config  │   │
│  └──────────────────────────────────────   │
│                                             │
│  Services:                                  │
│  - Frigate (Docker container)               │
│  - Home Assistant (Docker, host network)    │
│  - WireGuard (systemd wg-quick@wg0)        │
│  - dnsmasq (DNS server)                    │
│  - ddclient (DDNS via Cloudflare)          │
└─────────────────────────────────────────────┘
         ▲
         │ WireGuard VPN (10.8.0.0/24)
         │
    [ Internet ]
```

### Network Access Model

The nginx reverse proxy classifies clients into three tiers:

1. **LAN** (192.168.0.0/24) - Full access, no auth required
2. **VPN** (10.8.0.0/24) - Full access via WireGuard tunnel
3. **Internet** - Restricted to info page only

**Critical for iOS**: The app must establish VPN connection **before** making API calls to access services.

---

## API Endpoints (All via nginx)

All endpoints require VPN connection if not on LAN. All support CORS with credentials.

### Network Detection
```
GET http://192.168.0.200/whoami
Response: {"network":"lan|vpn|internet", "ip":"x.x.x.x"}
```

**iOS Usage**: Check this endpoint to determine if VPN is needed. If `network != "lan"`, activate VPN tunnel.

### Frigate (Security Cameras)

```
GET http://192.168.0.200/frigate/api/version
GET http://192.168.0.200/frigate/api/config
GET http://192.168.0.200/frigate/api/events
GET http://192.168.0.200/frigate/api/stats
GET http://192.168.0.200/frigate/api/{camera_name}/latest.jpg
WebSocket: ws://192.168.0.200/frigate/ws (live events)
```

**Configured Cameras**:
- `front_door` (1280x720, person detection enabled)
- `backyard` (1920x1080, person detection enabled)

### Home Assistant

```
GET http://192.168.0.200/homeassistant/api/
GET http://192.168.0.200/homeassistant/api/config
GET http://192.168.0.200/homeassistant/api/states
GET http://192.168.0.200/homeassistant/api/states/{entity_id}
POST http://192.168.0.200/homeassistant/api/services/{domain}/{service}
WebSocket: ws://192.168.0.200/homeassistant/api/websocket
```

**Authorization**: nginx auto-injects `Authorization: Bearer {token}` from vault if client doesn't provide one. For iOS, **you can skip auth headers** when accessing via the proxy.

### Climate Control (Thermostat)

```
GET http://192.168.0.200/climate/api/states/climate.sensi_20bd55_thermostat

Response:
{
  "entity_id": "climate.sensi_20bd55_thermostat",
  "state": "heat",
  "attributes": {
    "current_temperature": 69,
    "temperature": 67,
    "target_temp_high": null,
    "target_temp_low": null,
    "hvac_modes": ["off", "heat", "cool", "heat_cool"],
    "hvac_action": "idle",
    ...
  }
}

# Set temperature
POST http://192.168.0.200/climate/api/services/climate/set_temperature
Body: {
  "entity_id": "climate.sensi_20bd55_thermostat",
  "temperature": 70
}
```

### Roku TV Remote

Via Home Assistant:

```
# Entity: media_player.roku_*
POST http://192.168.0.200/homeassistant/api/services/media_player/media_play
POST http://192.168.0.200/homeassistant/api/services/media_player/media_pause
POST http://192.168.0.200/homeassistant/api/services/remote/send_command

# Send remote button
POST http://192.168.0.200/homeassistant/api/services/remote/send_command
Body: {
  "entity_id": "remote.roku_*",
  "command": ["Home", "Up", "Down", "Select", "Back", "VolumeUp", etc.]
}
```

---

## WireGuard VPN Configuration

### Server Details
- **Endpoint**: Dynamic DNS via Cloudflare (check vault for FQDN)
- **Port**: Variable (check `ansible/inventory/group_vars/pi/vars.yml` for `wireguard_port`)
- **Network**: 10.8.0.0/24
- **Server IP**: 10.8.0.1
- **Client IP**: 10.8.0.2

### Getting WireGuard Config

**Option 1: Download from Pi (when on LAN)**
```bash
curl http://192.168.0.200/household.conf > household.conf
```

**Option 2: Generate from Ansible vault**

The vault contains:
- `wireguard_server_private_key`
- `wireguard_household_private_key`
- `wireguard_household_public_key`

Template is at: `ansible/roles/wireguard/templates/household.conf.j2`

### iOS Integration Strategy

**Recommended**: Use Apple's NetworkExtension framework with WireGuardKit

1. **Add WireGuardKit** via Swift Package Manager:
   ```
   https://github.com/WireGuard/wireguard-apple.git
   ```

2. **Embed config in app** (don't require user to scan QR):
   - Extract keys from vault during build
   - Embed as config file or hardcode in secure enclave
   - Auto-activate VPN on app launch if not on LAN

3. **Network detection flow**:
   ```swift
   // 1. Check if on LAN
   let whoami = await checkWhoami()
   
   if whoami.network == "lan" {
       // Direct access, no VPN needed
       return
   }
   
   // 2. Activate VPN tunnel
   await activateWireGuard()
   
   // 3. Wait for tunnel establishment
   await waitForVPN()
   
   // 4. Verify VPN connected
   let recheck = await checkWhoami()
   guard recheck.network == "vpn" else {
       throw VPNError.connectionFailed
   }
   
   // 5. Proceed with API calls
   ```

4. **Background refresh**: Keep VPN alive with on-demand rules or periodic keepalive

---

## Current Flutter Web App Structure

Located in `home_dashboard/lib/`

### Key Pages & Features

#### 1. **Cameras Page** (`cameras_page.dart`)
- Displays grid of camera feeds from Frigate
- Uses `/frigate/api/{camera}/latest.jpg` with periodic refresh
- Shows motion detection events
- Fullscreen view for individual cameras

**iOS Equivalent**: Native SwiftUI grid with AsyncImage or custom image loader

#### 2. **HVAC Page** (`hvac_page.dart`)
- Shows current temperature, target, and humidity
- Circular temperature dial (similar to Nest)
- Mode switcher (Off/Heat/Cool/Auto)
- Uses `/climate/api/states/climate.sensi_20bd55_thermostat`

**iOS Equivalent**: Custom circular control with SwiftUI Gestures, SF Symbols for icons

#### 3. **Media Control Page** (`media_control_page.dart`)
- Roku TV remote interface
- D-pad navigation (Up/Down/Left/Right/Select)
- Transport controls (Play/Pause/Rewind/FastForward)
- Channel shortcuts
- Volume controls
- Uses HA remote service calls

**iOS Equivalent**: Native button grid with haptic feedback

#### 4. **Navigation** (`main.dart`)
- Bottom tab bar with Home/Cameras/HVAC/Media
- Network status indicator (shows LAN/VPN/offline)
- Auto-refresh on tab switch

**iOS Equivalent**: UITabBarController or SwiftUI TabView

### Services Layer

**`climate_service.dart`**:
```dart
class ClimateService {
  static const baseUrl = 'http://192.168.0.200/climate';
  
  Future<ClimateState> getState() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/states/climate.sensi_20bd55_thermostat')
    );
    return ClimateState.fromJson(jsonDecode(response.body));
  }
  
  Future<void> setTemperature(double temp) async {
    await http.post(
      Uri.parse('$baseUrl/api/services/climate/set_temperature'),
      body: jsonEncode({
        'entity_id': 'climate.sensi_20bd55_thermostat',
        'temperature': temp,
      }),
    );
  }
}
```

**iOS Translation**: Use URLSession with async/await or Combine publishers

**`frigate_service.dart`**: Similar pattern for camera data

**`home_assistant_service.dart`**: WebSocket connection for real-time updates

---

## Data Models (for iOS translation)

### Climate State
```swift
struct ClimateState: Codable {
    let entityId: String
    let state: String  // "heat", "cool", "off", "heat_cool"
    let attributes: ClimateAttributes
    let lastChanged: Date
    
    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state, attributes
        case lastChanged = "last_changed"
    }
}

struct ClimateAttributes: Codable {
    let currentTemperature: Double
    let temperature: Double
    let targetTempHigh: Double?
    let targetTempLow: Double?
    let hvacModes: [String]
    let hvacAction: String
    let friendlyName: String
    
    enum CodingKeys: String, CodingKey {
        case currentTemperature = "current_temperature"
        case temperature
        case targetTempHigh = "target_temp_high"
        case targetTempLow = "target_temp_low"
        case hvacModes = "hvac_modes"
        case hvacAction = "hvac_action"
        case friendlyName = "friendly_name"
    }
}
```

### Frigate Event
```swift
struct FrigateEvent: Codable {
    let id: String
    let camera: String
    let label: String  // "person", "car", etc.
    let score: Double
    let startTime: Double
    let endTime: Double?
    let hasSnapshot: Bool
    let thumbnailPath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, camera, label, score
        case startTime = "start_time"
        case endTime = "end_time"
        case hasSnapshot = "has_snapshot"
        case thumbnailPath = "thumbnail_path"
    }
}
```

### Network Status
```swift
struct NetworkStatus: Codable {
    let network: NetworkType
    let ip: String
    
    enum NetworkType: String, Codable {
        case lan
        case vpn
        case internet
    }
}
```

---

## iOS-Specific Considerations

### 1. VPN Permissions & Entitlements

Required entitlements in Xcode:
```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
```

**Info.plist additions**:
```xml
<key>Privacy - Network Extensions Usage Description</key>
<string>Required to securely connect to your home automation system</string>
```

### 2. Background Modes

Enable in Xcode capabilities:
- **Background fetch** (periodic camera/event updates)
- **Remote notifications** (for motion alerts from Frigate)

### 3. Local Network Privacy (iOS 14+)

Add to Info.plist:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Access your home automation when on the same WiFi network</string>
<key>NSBonjourServices</key>
<array>
    <string>_homeassistant._tcp</string>
</array>
```

### 4. Camera/Image Loading

For Frigate camera feeds, use:
```swift
// Periodic refresh
Timer.publish(every: 1.0, on: .main, in: .common)
    .autoconnect()
    .sink { _ in
        self.refreshCameraImage()
    }

func refreshCameraImage() async {
    let url = URL(string: "http://192.168.0.200/frigate/api/front_door/latest.jpg")!
    let (data, _) = try await URLSession.shared.data(from: url)
    self.cameraImage = UIImage(data: data)
}
```

### 5. WebSocket for Real-time Updates

Use URLSessionWebSocketTask or Starscream library:
```swift
let socket = URLSession.shared.webSocketTask(
    with: URL(string: "ws://192.168.0.200/homeassistant/api/websocket")!
)
socket.resume()

// Subscribe to state changes
let message = [
    "type": "subscribe_events",
    "event_type": "state_changed"
]
socket.send(.string(JSONEncoder().encode(message))) { error in
    // Handle
}

socket.receive { result in
    // Parse events
}
```

### 6. Persistent VPN Connection

Use NEOnDemandRule to auto-connect VPN:
```swift
let onDemandRule = NEOnDemandRuleConnect()
onDemandRule.interfaceTypeMatch = .any

// Connect when accessing home automation
onDemandRule.dnsSearchDomainMatch = ["local"]

tunnelConfig.onDemandRules = [onDemandRule]
```

---

## Development & Testing

### Health Check Script

Run to verify all services:
```bash
./ops/health_check.sh 192.168.0.200
```

Validates:
- ✓ Network connectivity
- ✓ All HTTP endpoints (/frigate/, /homeassistant/, /climate/, /whoami)
- ✓ CORS configuration
- ✓ System services (Docker, WireGuard, etc.)
- ✓ Running containers

### Local Testing Without VPN

When developing on the same LAN as the Pi:
```swift
// iOS will detect network="lan" and skip VPN
let config = NetworkConfig(
    baseURL: "http://192.168.0.200",
    requiresVPN: false  // Auto-detected via /whoami
)
```

### Testing VPN Flow

1. Disable WiFi on iOS device (use cellular)
2. App should detect `network="internet"` from `/whoami`
3. Activate WireGuard tunnel
4. Recheck `/whoami` should return `network="vpn"`
5. All APIs now accessible

### Simulator Testing

Since simulator can't connect to physical network:
- Mock the `/whoami` endpoint
- Use Charles Proxy or similar to redirect API calls
- Or run the simulation environment: `make sim-up`

---

## Repository Structure Reference

```
crooked-services/
├── ansible/                    # Infrastructure as Code
│   ├── site.yml               # Main playbook
│   ├── inventory/
│   │   └── group_vars/pi/
│   │       ├── vars.yml       # Public config
│   │       └── vault.yml      # Secrets (WireGuard keys, tokens)
│   ├── roles/
│   │   ├── nginx/             # Reverse proxy config
│   │   ├── frigate/           # Camera NVR setup
│   │   ├── homeassistant/     # Smart home hub
│   │   ├── wireguard/         # VPN server
│   │   └── ...
│   └── templates/
│       └── nginx/
│           └── site.conf.j2   # ⭐ CORS, paths, auth injection
├── home_dashboard/            # 📱 Current Flutter web app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── pages/
│   │   │   ├── cameras_page.dart
│   │   │   ├── hvac_page.dart
│   │   │   └── media_control_page.dart
│   │   └── services/
│   │       ├── climate_service.dart
│   │       ├── frigate_service.dart
│   │       └── home_assistant_service.dart
│   └── pubspec.yaml
├── ops/
│   ├── health_check.sh        # Verify all services
│   └── bootstrap_pi.sh
├── docs/
│   └── IOS_HANDOFF.md         # ⭐ This document
└── Makefile                   # Deployment commands
```

---

## Getting Started (iOS Developer)

### Prerequisites

1. **Get WireGuard Config**:
   ```bash
   # From this repo
   cd crooked-services
   curl http://192.168.0.200/household.conf > ios-app/wireguard-config.conf
   ```

2. **Extract keys from config** or get from Ansible vault:
   ```bash
   make vault-edit
   # Look for wireguard_household_private_key and server details
   ```

3. **Test endpoints manually**:
   ```bash
   # Verify CORS and responses
   curl -i -H "Origin: http://localhost:3000" \
     http://192.168.0.200/climate/api/states/climate.sensi_20bd55_thermostat
   ```

### Suggested iOS Project Structure

```
HomeDashboard-iOS/
├── App/
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Core/
│   ├── Network/
│   │   ├── NetworkManager.swift       # VPN + API client
│   │   ├── WireGuardManager.swift     # Tunnel management
│   │   └── APIEndpoints.swift
│   ├── Models/
│   │   ├── ClimateState.swift
│   │   ├── FrigateEvent.swift
│   │   └── NetworkStatus.swift
│   └── Services/
│       ├── ClimateService.swift
│       ├── FrigateService.swift
│       └── HomeAssistantService.swift
├── Features/
│   ├── Cameras/
│   │   ├── CamerasView.swift
│   │   └── CameraViewModel.swift
│   ├── Climate/
│   │   ├── ClimateView.swift
│   │   ├── ClimateViewModel.swift
│   │   └── TemperatureDial.swift      # Custom circular control
│   └── MediaControl/
│       ├── MediaControlView.swift
│       └── RokuRemoteView.swift       # D-pad + buttons
└── Resources/
    ├── wireguard-config.conf          # Embedded VPN config
    └── Assets.xcassets
```

### Key iOS Classes to Implement

**1. WireGuardManager.swift**
```swift
import NetworkExtension
import WireGuardKit

class WireGuardManager {
    func setupTunnel(config: WireGuardConfig) async throws
    func connect() async throws
    func disconnect()
    func getStatus() -> NEVPNStatus
    var isConnected: Bool { get }
}
```

**2. NetworkManager.swift**
```swift
class NetworkManager {
    let wireGuard: WireGuardManager
    
    func checkNetworkStatus() async -> NetworkStatus
    func ensureConnected() async throws  // Auto VPN if needed
    
    // Generic API request wrapper
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        body: Data? = nil
    ) async throws -> T
}
```

**3. ClimateService.swift**
```swift
class ClimateService {
    let network: NetworkManager
    
    func getCurrentState() async throws -> ClimateState
    func setTemperature(_ temp: Double) async throws
    func setMode(_ mode: HVACMode) async throws
}
```

### Migration Path from Flutter

1. **Start with read-only views**:
   - Camera grid (easiest, just image loading)
   - HVAC display (no controls yet)

2. **Add VPN integration**:
   - NetworkManager + WireGuardManager
   - Auto-detect LAN vs remote

3. **Add write operations**:
   - HVAC temperature control
   - Roku remote buttons

4. **Polish**:
   - Haptic feedback
   - Widgets (camera snapshots, current temp)
   - Push notifications (motion alerts)
   - Apple Watch complications

---

## Known Issues & Solutions

### 1. CORS Errors
**Already fixed** in nginx config. All endpoints return:
```
Access-Control-Allow-Origin: {origin}
Access-Control-Allow-Credentials: true
```

For iOS, use:
```swift
var request = URLRequest(url: url)
request.setValue("http://your-app-origin", forHTTPHeaderField: "Origin")
```

### 2. Home Assistant WebSocket Auth
When using WebSocket (for real-time updates), you need to authenticate:
```json
// 1. Connect to ws://192.168.0.200/homeassistant/api/websocket
// 2. Receive auth_required message
// 3. Send auth message (token auto-injected by nginx for HTTP, but not WS)
{
    "type": "auth",
    "access_token": "YOUR_HA_TOKEN"  // Get from vault
}
```

### 3. VPN Packet Routing
If VPN connects but APIs still fail:
- Check `/whoami` returns `"network":"vpn"`
- Verify allowed IPs in WireGuard config: `10.8.0.0/24, 192.168.0.0/24`
- Ensure route table includes Pi's LAN subnet

---

## Secrets Management (iOS)

**DO NOT** hardcode WireGuard private key in source code!

Options:

1. **Keychain** (recommended):
   ```swift
   let keychain = KeychainAccess(service: "com.yourapp.wireguard")
   keychain["private_key"] = privateKey
   ```

2. **Build-time injection**:
   ```bash
   # In Xcode Build Phases
   echo "${WIREGUARD_PRIVATE_KEY}" > Config.generated.swift
   ```

3. **User enrollment flow** (most secure):
   - QR code scan on first launch
   - Extract keys from scanned config
   - Store in Keychain

---

## Performance Targets

Based on Flutter web app performance:

- **Camera image refresh**: 1 FPS (adequate for snapshot view)
- **HVAC state polling**: Every 5 seconds
- **WebSocket latency**: <100ms for button presses
- **VPN connection time**: <3 seconds
- **Cold app launch**: <2 seconds to first UI

iOS should meet or exceed these with:
- Native networking stack
- Persistent VPN connection
- Background refresh capabilities

---

## Next Steps for iOS Developer

### Phase 1: Foundation (Week 1)
- [ ] Set up Xcode project with SwiftUI
- [ ] Add WireGuardKit dependency
- [ ] Implement NetworkManager with `/whoami` check
- [ ] Implement WireGuardManager with embedded config
- [ ] Create mock data models (Climate, Camera, etc.)

### Phase 2: Read-Only Views (Week 2)
- [ ] Camera grid view with periodic image refresh
- [ ] HVAC display view (no controls)
- [ ] Network status indicator
- [ ] Test on LAN (no VPN)

### Phase 3: VPN Integration (Week 3)
- [ ] Auto-connect VPN when off LAN
- [ ] Handle VPN state transitions
- [ ] Test all views over VPN
- [ ] Error handling & retry logic

### Phase 4: Interactive Controls (Week 4)
- [ ] HVAC temperature dial with gestures
- [ ] Mode switcher (Heat/Cool/Auto/Off)
- [ ] Roku remote button grid
- [ ] API write operations

### Phase 5: Polish (Week 5+)
- [ ] Haptic feedback
- [ ] Push notifications (motion alerts)
- [ ] Home screen widgets
- [ ] Apple Watch app
- [ ] Siri shortcuts

---

## Support Resources

### Contact Points
- **Backend infrastructure**: Managed via Ansible in this repo
- **API documentation**: See this document + test with `curl` examples
- **WireGuard issues**: Check `ansible/roles/wireguard/` for server config

### Testing Credentials
All in Ansible vault (`make vault-edit`):
- Home Assistant long-lived access token: `ha_token_long`
- WireGuard keys: `wireguard_household_private_key`, etc.
- Cloudflare DDNS endpoint (for remote access)

### Deployment
Backend changes deployed via:
```bash
make deploy
```

Health verification:
```bash
./ops/health_check.sh
```

---

## FAQ

**Q: Why not use the existing Flutter app compiled for iOS?**
A: Flutter apps can't integrate native VPN (NetworkExtension) effectively, and the web-based architecture doesn't provide the native feel expected on iOS.

**Q: Can the iOS app work without VPN when on LAN?**
A: Yes! The `/whoami` endpoint detects LAN access and skips VPN activation.

**Q: How do I get the latest WireGuard config?**
A: Either download from `http://192.168.0.200/household.conf` when on LAN, or extract from Ansible vault in this repo.

**Q: What if the Pi's IP changes?**
A: It won't - it's configured with a static IP (192.168.0.200). For remote access, use the DDNS hostname (in vault).

**Q: Can multiple household members use the app?**
A: Yes, but currently there's one shared WireGuard key. For multi-user, generate additional client configs via Ansible role.

**Q: Where are the camera snapshots stored?**
A: Frigate stores events on the Pi's NVMe drive at `/media/frigate`. The `/latest.jpg` endpoint is dynamically generated.

---

## Conclusion

This infrastructure provides a solid foundation for a native iOS app. All backend APIs are stable, CORS-enabled, and well-tested. The main iOS development tasks are:

1. **VPN integration** (WireGuardKit + NetworkExtension)
2. **UI translation** (SwiftUI versions of Flutter pages)
3. **Service layer** (URLSession wrappers for APIs)

The architecture is designed to be iOS-friendly: stateless HTTP APIs, auto-injected auth, and network-aware access control. The VPN integration will be the most complex piece but dramatically improves UX by eliminating manual VPN configuration.

Good luck! 🚀
