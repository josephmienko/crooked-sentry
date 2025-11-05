# Crooked Sentry Simulation Environment

This directory contains Docker-based simulation of the Raspberry Pi environment
for testing the complete crooked-services architecture locally.

## Purpose

The simulation serves two critical functions:

1. **Infrastructure Testing**: Test infrastructure deployments (nginx, Frigate, WireGuard, etc.) 
   in a Docker container before deploying them to the actual Raspberry Pi. This allows you to 
   validate Ansible playbooks, configuration templates, and service configurations in a safe, 
   reproducible environment.

2. **Mock Resources for Dashboard Development**: Provide mock resources (Frigate API, camera feeds, 
   network endpoints) that can be used for testing the Flutter dashboard maintained in the 
   [crooked-services-dashboard](https://github.com/josephmienko/crooked-services-dashboard) repository.
   This enables frontend development without requiring the physical Raspberry Pi or real cameras.

## Architecture

- **Base Image**: ARM64 Raspberry Pi OS (Debian-based)
- **Emulation**: Docker BuildKit with ARM64 emulation 
- **Services**: All crooked-services services running in simulated Pi container
- **Testing**: Full end-to-end verification without physical hardware
- **Mock Cameras**: PIL-generated camera feeds (no real cameras required)

### Network Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Your Machine (macOS)                                       │
│                                                             │
│  Flutter Dashboard                                          │
│  baseUrl: http://localhost:8080                            │
│                                                             │
│  Request: GET /api/front_door/latest.jpg                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           │ Port 8080
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Docker Container: crooked-services-pi-sim                    │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │ nginx (Port 80)                                     │    │
│  │                                                     │    │
│  │ location /api/ {                                    │    │
│  │   proxy_pass http://localhost:5000/api/;           │    │
│  │ }                                                   │    │
│  └──────────────────────┬──────────────────────────────┘    │
│                         │                                   │
│                         │ Internal: localhost:5000          │
│                         ▼                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Frigate Simulation (Port 5000)                      │    │
│  │ - Python HTTP Server                                │    │
│  │ - PIL-generated snapshots                           │    │
│  │ - Mock API responses                                │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Port Mapping:
  - 8080 → 80   (nginx, recommended for dashboard)
  - 15000 → 5000 (direct Frigate access, for debugging)
```

This matches the production setup where nginx on the Pi proxies to Frigate.

## Usage

**Note:** After recent updates adding PIL support for mock camera snapshots, you'll need to rebuild the simulation:

```bash
# Clean and rebuild simulation with PIL support
make sim-clean
make sim-up
```

Once rebuilt, use these commands:

```bash
# Initialize simulation script (verifies script exists)
make init-sim

# Build and run simulation
make sim-up

# Test all three requirements
make sim-test

# Test camera snapshots specifically
make sim-test-snapshots

# View logs
make sim-logs

# Shell access
make sim-shell

# Clean up
make sim-clean
```

### Running without Docker (quick local dev)

If Docker Desktop is unavailable or returns a 500 error, you can run the Frigate simulation directly on your Mac:

```bash
# Start the server on port 5500 (auto-installs Pillow if missing)
./simulation/run-local.sh

# In another terminal, test endpoints directly
curl http://localhost:5500/api/version
curl http://localhost:5500/api/events | jq 'length'   # should print 20
curl -o front.jpg  http://localhost:5500/api/front_door/latest.jpg
curl -o thumb.jpg   http://localhost:5500/api/events/evt_002/thumbnail.jpg
```

Notes:
- macOS AirPlay may use port 5000; the local runner defaults to port 5500 to avoid conflicts.
- CORS headers are enabled in the simulation server, so you can point your Flutter app at `http://localhost:5500` during local dev.


## Frigate Mock Camera Feeds

The simulation includes a Python-based Frigate mock server (`scripts/frigate-sim.py`) that:

- ✅ Generates camera snapshots using PIL (no real cameras needed)
- ✅ Updates timestamps on each request to simulate live feeds
- ✅ Provides full Frigate API endpoints:
  - `/api/version` - Frigate version info
  - `/api/config` - Camera configuration
  - `/api/events` - Mock detection events
  - `/api/stats` - System statistics
  - `/api/{camera}/latest.jpg` - Generated camera snapshots
- ✅ Mock cameras: `front_door` (1280x720), `backyard` (1920x1080)

### Testing Camera Feeds

The Frigate API is accessible through nginx on port 8080 (recommended for dashboard development) or directly on port 15000:

```bash
# Start simulation
make sim-up

# Test camera snapshots via nginx (use these URLs in your dashboard)
curl http://localhost:8080/api/front_door/latest.jpg > front_door.jpg
curl http://localhost:8080/api/backyard/latest.jpg > backyard.jpg

# Test API endpoints via nginx
curl http://localhost:8080/api/version
curl http://localhost:8080/api/config
curl http://localhost:8080/api/events

# Direct Frigate access (bypasses nginx, not recommended for dashboard)
curl http://localhost:15000/api/version
```

**For Flutter Dashboard Development:**

Configure your dashboard to use `http://localhost:8080` as the base URL. The nginx proxy will forward all `/api/*` requests to the Frigate simulation, matching the production setup where nginx proxies to Frigate on the Raspberry Pi.

## Components Simulated

- ✅ Docker CE ARM64 installation
- ✅ nginx reverse proxy with geo-routing
- ✅ Frigate camera system (with PIL-generated mock feeds)
- ✅ Home Assistant API (with Roku media player integration)
- ✅ WireGuard VPN server
- ✅ ddclient DNS updates  
- ✅ dnsmasq local DNS
- ✅ Complete networking stack

## Home Assistant Integration

The simulation includes a Home Assistant API server that provides smart home control capabilities. Currently includes:

### Roku Media Player

- **Entity ID**: `media_player.roku`
- **Capabilities**: 
  - Turn on/off
  - Play/pause/stop media
  - Volume control (set, up, down, mute)
  - Source selection (Netflix, Hulu, Disney+, YouTube, etc.)
  - Media navigation (next/previous track)

### Running Home Assistant Locally

```bash
# Start the Home Assistant server on port 8123
./simulation/run-homeassistant.sh

# In another terminal, test endpoints
curl http://localhost:8123/api/
curl http://localhost:8123/api/config
curl http://localhost:8123/api/states/media_player.roku

# Control the Roku
curl -X POST http://localhost:8123/api/services/media_player/select_source \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "media_player.roku", "source": "Netflix"}'

curl -X POST http://localhost:8123/api/services/media_player/media_play \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "media_player.roku"}'
```

### Via nginx proxy (in Docker)

When running the full simulation via Docker, Home Assistant is accessible through nginx:

```bash
# Access via proxy on port 8080
curl http://localhost:8080/homeassistant/api/
curl http://localhost:8080/homeassistant/api/states/media_player.roku
```

### Adding More Entities

To add more entities (lights, sensors, switches, etc.):

1. Create state JSON files in `simulation/data/homeassistant/`
2. Update `homeassistant-sim.py` to load them at startup
3. Add corresponding service handlers in the `handle_service_call` method

Example state file structure:
```json
{
  "entity_id": "light.living_room",
  "state": "on",
  "attributes": {
    "friendly_name": "Living Room Light",
    "brightness": 255,
    "supported_features": 1
  }
}
```