# iOS App Configuration Reference

This document provides all the concrete values needed to configure the iOS native app.

---

## WireGuard VPN Configuration

### Server Details
```swift
// WireGuard server endpoint
let serverEndpoint = "cameras.crookedsentry.net:51820"
let serverPublicKey = "JP2rKc7SKSiYc063Pc+1RdVTqbSna6BU7/VpHLgFOVg="

// Client (household) credentials
let clientPrivateKey = "SGdN1e0bItaoAqwjaIWH0Qocy7Dtr7XPl/0uGs5VsHI="
let clientPublicKey = "ure4Xnk8phiHtw6NkNYgZqqWUCtO8wTVu0STxBhkSUc="
let clientAddress = "10.8.0.2/32"
```

### Network Settings
```swift
// AllowedIPs - Route ALL traffic through VPN (including LAN access)
let allowedIPs = ["0.0.0.0/0", "::/0"]

// DNS servers while on VPN
let dnsServers = ["1.1.1.1"]  // Cloudflare DNS

// MTU (Maximum Transmission Unit)
let mtu = 1420  // Standard for WireGuard, works with most networks

// PersistentKeepalive - Keep connection alive through NAT
let persistentKeepalive = 25  // seconds
```

### Full WireGuard Config (for reference)
```ini
[Interface]
PrivateKey = SGdN1e0bItaoAqwjaIWH0Qocy7Dtr7XPl/0uGs5VsHI=
Address = 10.8.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = JP2rKc7SKSiYc063Pc+1RdVTqbSna6BU7/VpHLgFOVg=
Endpoint = cameras.crookedsentry.net:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

---

## Network Architecture

### IP Addressing Scheme
- **LAN Subnet**: 192.168.0.0/24
- **Pi Static IP**: 192.168.0.200
- **VPN Subnet**: 10.8.0.0/24
- **VPN Server**: 10.8.0.1
- **VPN Client (household)**: 10.8.0.2

### When on LAN (Home WiFi)
- App detects `network="lan"` from `/whoami`
- Direct access to `http://192.168.0.200`
- No VPN needed

### When on VPN (Remote/Cellular)
- App detects `network="internet"` from `/whoami`
- Activates WireGuard tunnel
- Routes to Pi via `10.8.0.1` → `192.168.0.200`
- `/whoami` returns `network="vpn"`

---

## API Endpoints

### Base URLs
```swift
// When on LAN
let lanBaseURL = "http://192.168.0.200"

// When on VPN (same, routed through tunnel)
let vpnBaseURL = "http://192.168.0.200"

// For external access (DDNS)
let externalURL = "http://cameras.crookedsentry.net"  // Only if port forwarding enabled
```

### Network Detection
```swift
GET http://192.168.0.200/whoami

// Response when on LAN:
{"network":"lan","ip":"192.168.0.14"}

// Response when on VPN:
{"network":"vpn","ip":"10.8.0.2"}

// Response when on internet (before VPN):
{"network":"internet","ip":"<public_ip>"}
```

### Key Endpoints
```swift
// Frigate (cameras)
/frigate/api/version
/frigate/api/config
/frigate/api/events
/frigate/api/front_door/latest.jpg
/frigate/api/backyard/latest.jpg
ws://192.168.0.200/frigate/ws

// Home Assistant (smart home hub)
/homeassistant/api/
/homeassistant/api/states
/homeassistant/api/services/{domain}/{service}
ws://192.168.0.200/homeassistant/api/websocket

// Climate (thermostat)
/climate/api/states/climate.sensi_20bd55_thermostat
/climate/api/services/climate/set_temperature
```

---

## Authentication & Security

### Home Assistant Long-Lived Access Token
**Note**: The nginx proxy **auto-injects** this token for HTTP requests, so iOS app doesn't need to provide it for REST API calls.

However, for **WebSocket** connections, you'll need to authenticate:

```swift
// After connecting to ws://192.168.0.200/homeassistant/api/websocket
// Send auth message:
{
    "type": "auth",
    "access_token": "YOUR_HA_TOKEN_HERE"  // Get from backend vault
}
```

**Recommendation**: For initial version, skip WebSocket and use REST polling. Add WebSocket later for real-time updates.

### Camera Credentials
All cameras use the same credentials:
- **Username**: `admin`
- **Password**: `DavidAlan`

**Note**: These are embedded in Frigate config, not used by iOS app directly.

---

## iOS App Configuration

### Xcode Entitlements
```xml
<!-- Required for VPN functionality -->
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>

<!-- Optional: App Groups for sharing data between main app and VPN extension -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.crookedservices</string>
</array>
```

### Info.plist Requirements
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Access your home automation when on the same WiFi network</string>

<key>Privacy - Network Extensions Usage Description</key>
<string>Required to securely connect to your home automation system when away from home</string>

<key>NSBonjourServices</key>
<array>
    <string>_homeassistant._tcp</string>
</array>
```

### Suggested App Group Identifier
```
group.com.yourcompany.crookedservices
```
or
```
group.net.crookedservices.app
```

**Purpose**: Share VPN connection state and credentials between:
1. Main app (UI)
2. Network Extension (VPN tunnel provider)
3. Potential widgets/watch app

---

## Network Tuning

### MTU (Maximum Transmission Unit)
**Recommended**: `1420`

**Why**: 
- Standard Ethernet MTU is 1500
- WireGuard overhead is ~80 bytes
- 1420 provides headroom for most networks
- Alternative: 1280 for networks with stricter limits

```swift
// In WireGuardKit config
tunnelConfiguration.mtu = 1420
```

### PersistentKeepalive
**Value**: `25` seconds

**Purpose**: 
- Keeps NAT mappings alive
- Ensures connection persists through mobile network changes
- Recommended for mobile devices

```swift
// In peer configuration
peerConfiguration.persistentKeepAlive = 25
```

### DNS Configuration
**Primary DNS**: `1.1.1.1` (Cloudflare)

**Alternative**: `192.168.0.200` (Pi's dnsmasq)
- Only if you want local DNS resolution for `.local` domains
- May cause issues when VPN is off

**Recommendation**: Stick with `1.1.1.1` for simplicity.

---

## Health & Diagnostics

### Primary Health Check Endpoint
```swift
GET http://192.168.0.200/whoami

// Returns:
{
    "network": "lan|vpn|internet",
    "ip": "x.x.x.x"
}

// Use this to:
// 1. Determine if VPN is needed
// 2. Verify VPN connection succeeded
// 3. Show network status in UI
```

### Additional Diagnostics Endpoints

#### Frigate Health
```swift
GET http://192.168.0.200/frigate/api/version
// Returns: "0.16.2-4d58206"

GET http://192.168.0.200/frigate/api/stats
// Returns: CPU, memory, camera stats
```

#### Home Assistant Health
```swift
GET http://192.168.0.200/homeassistant/api/
// Returns: {"message":"API running."}

GET http://192.168.0.200/homeassistant/api/config
// Returns: Full HA config including version
```

#### Climate (Thermostat) Health
```swift
GET http://192.168.0.200/climate/api/states/climate.sensi_20bd55_thermostat
// Returns: Current state and temperature
```

### Suggested Health Check Strategy

```swift
struct HealthCheck {
    var vpnConnected: Bool = false
    var networkType: NetworkType = .unknown
    var frigateReachable: Bool = false
    var homeAssistantReachable: Bool = false
    var climateReachable: Bool = false
    
    enum NetworkType {
        case lan, vpn, internet, unknown
    }
}

func performHealthCheck() async -> HealthCheck {
    var health = HealthCheck()
    
    // 1. Check network type
    if let whoami = try? await fetchWhoami() {
        health.networkType = whoami.network
        health.vpnConnected = (whoami.network == .vpn)
    }
    
    // 2. Check Frigate
    health.frigateReachable = await checkEndpoint("/frigate/api/version")
    
    // 3. Check Home Assistant
    health.homeAssistantReachable = await checkEndpoint("/homeassistant/api/")
    
    // 4. Check Climate
    health.climateReachable = await checkEndpoint("/climate/api/states/climate.sensi_20bd55_thermostat")
    
    return health
}
```

---

## Camera Configuration

### Configured Cameras

#### Camera 1: "front_door" (cam1)
- **IP**: 192.168.0.210
- **Resolution**: 1280x720
- **Detection FPS**: 12
- **Features**: Person detection enabled

#### Camera 2: "backyard"
- **IP**: 192.168.0.211
- **Resolution**: 704x396
- **Detection FPS**: 8
- **Features**: Person detection enabled

### Camera Snapshot URLs
```swift
// Front door
http://192.168.0.200/frigate/api/front_door/latest.jpg

// Backyard
http://192.168.0.200/frigate/api/backyard/latest.jpg
```

**Refresh Rate**: Recommended 1 FPS (every 1 second) for live view.

---

## Smart Home Devices

### Thermostat (Sensi)
- **Entity ID**: `climate.sensi_20bd55_thermostat`
- **Model**: Sensi 20BD55
- **Modes**: Off, Heat, Cool, Heat/Cool (Auto)
- **Temperature Range**: 45°F - 100°F

### Roku TV
- **IP**: 192.168.0.220
- **Name**: "MC at the CC"
- **Entity ID**: `media_player.roku_*` and `remote.roku_*`
- **Discovery**: SSDP enabled on Pi
- **Remote Commands**: Home, Up, Down, Left, Right, Select, Back, Play, Pause, VolumeUp, VolumeDown, etc.

---

## Development & Testing URLs

### On LAN (Development)
```
http://192.168.0.200/whoami
http://192.168.0.200/frigate/api/version
http://192.168.0.200/homeassistant/api/
http://192.168.0.200/climate/api/states/climate.sensi_20bd55_thermostat
```

### Health Check Script (Backend)
From the repo:
```bash
./ops/health_check.sh 192.168.0.200
```

Validates all services are running and reachable.

---

## Provisioning Notes

### NetworkExtension Entitlement
Required for App Store distribution. Steps:

1. **Apple Developer Portal**:
   - Enable "Network Extensions" capability
   - Create App ID with NetworkExtension entitlement
   - Generate provisioning profile including this entitlement

2. **Xcode**:
   - Add "Packet Tunnel" capability
   - Select the provisioning profile with NetworkExtension

3. **Both Targets**:
   - Main app target
   - Network Extension target (for VPN tunnel provider)

### Testing on Device
- **Simulator**: Cannot test VPN; mock `/whoami` responses
- **Device**: Requires provisioning profile with NetworkExtension
- **TestFlight**: Works with production entitlements

---

## Security Considerations

### DO NOT Hardcode in Source
- ❌ WireGuard private keys
- ❌ HA access tokens
- ❌ Camera passwords

### Recommended Storage
1. **WireGuard Keys**: 
   - Store in iOS Keychain
   - Or embed encrypted in app bundle (decrypt on first launch)

2. **HA Token**:
   - Not needed for REST API (proxy injects it)
   - Only needed if implementing WebSocket
   - Store in Keychain if used

3. **Camera Passwords**:
   - Not needed by iOS app
   - Frigate handles camera auth

### App Transport Security (ATS)
Since the Pi uses HTTP (not HTTPS), add to Info.plist:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <!-- Or more restrictive: -->
    <key>NSExceptionDomains</key>
    <dict>
        <key>192.168.0.200</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Note**: This is acceptable for local network access. VPN traffic is already encrypted.

---

## Quick Reference Card

```swift
// === COPY-PASTE CONFIG ===

// WireGuard
let vpnEndpoint = "cameras.crookedsentry.net:51820"
let vpnServerPublicKey = "JP2rKc7SKSiYc063Pc+1RdVTqbSna6BU7/VpHLgFOVg="
let vpnClientPrivateKey = "SGdN1e0bItaoAqwjaIWH0Qocy7Dtr7XPl/0uGs5VsHI="
let vpnClientAddress = "10.8.0.2/32"
let vpnAllowedIPs = ["0.0.0.0/0", "::/0"]
let vpnDNS = ["1.1.1.1"]
let vpnMTU = 1420
let vpnKeepalive = 25

// Network
let piLANIP = "192.168.0.200"
let piVPNIP = "10.8.0.1"
let lanSubnet = "192.168.0.0/24"
let vpnSubnet = "10.8.0.0/24"

// API Base
let baseURL = "http://192.168.0.200"

// Key Endpoints
let whoamiURL = "\(baseURL)/whoami"
let frigateVersionURL = "\(baseURL)/frigate/api/version"
let haAPIURL = "\(baseURL)/homeassistant/api/"
let climateStateURL = "\(baseURL)/climate/api/states/climate.sensi_20bd55_thermostat"

// Cameras
let frontDoorSnapshotURL = "\(baseURL)/frigate/api/front_door/latest.jpg"
let backyardSnapshotURL = "\(baseURL)/frigate/api/backyard/latest.jpg"

// App Group (if using)
let appGroup = "group.net.crookedservices.app"
```

---

## FAQ

**Q: Why AllowedIPs = 0.0.0.0/0 instead of just 192.168.0.0/24?**

A: The current WireGuard config routes ALL traffic through VPN. This is simpler for mobile devices but uses more data. 

**Alternative** (for iOS optimization):
```swift
let vpnAllowedIPs = ["10.8.0.0/24", "192.168.0.0/24"]
```
This only routes home network traffic through VPN, saving cellular data.

**Q: Should I use the Pi's dnsmasq (192.168.0.200) as DNS?**

A: No, use 1.1.1.1 instead:
- Simpler configuration
- Works even when VPN is disconnected
- Avoids DNS leaks
- Pi's dnsmasq is for LAN devices, not VPN clients

**Q: Do I need HTTPS?**

A: No, because:
- Traffic is encrypted by WireGuard when on VPN
- On LAN, you're on trusted network
- Setting up TLS for local IP is complex

**Q: Where can I test these endpoints?**

A: Run the health check script from this repo:
```bash
cd crooked-services
./ops/health_check.sh 192.168.0.200
```

All endpoints should return 200 OK with CORS headers.

---

## Summary Checklist

- [x] WireGuard port: **51820**
- [x] AllowedIPs: **0.0.0.0/0, ::/0** (or 10.8.0.0/24, 192.168.0.0/24 for optimization)
- [x] DNS servers: **1.1.1.1**
- [x] HA token: **Not needed** (proxy auto-injects for REST)
- [x] App Group: **group.net.crookedservices.app** (suggested)
- [x] NetworkExtension entitlement: **Required** (via Apple Developer Portal)
- [x] MTU: **1420**
- [x] PersistentKeepalive: **25 seconds**
- [x] Health/diagnostics: **/whoami** primary, see diagnostics section for others

All values are production-ready and tested! 🚀
