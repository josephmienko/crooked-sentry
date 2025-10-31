# Crooked Sentry Simulation Environment

This directory contains Docker-based simulation of the Raspberry Pi environment
for testing the complete crooked-sentry architecture locally.

## Purpose

The simulation serves two critical functions:

1. **Infrastructure Testing**: Test infrastructure deployments (nginx, Frigate, WireGuard, etc.) 
   in a Docker container before deploying them to the actual Raspberry Pi. This allows you to 
   validate Ansible playbooks, configuration templates, and service configurations in a safe, 
   reproducible environment.

2. **Mock Resources for Dashboard Development**: Provide mock resources (Frigate API, camera feeds, 
   network endpoints) that can be used for testing the Flutter dashboard maintained in the 
   [crooked-sentry-dashboard](https://github.com/josephmienko/crooked-sentry-dashboard) repository.
   This enables frontend development without requiring the physical Raspberry Pi or real cameras.

## Architecture

- **Base Image**: ARM64 Raspberry Pi OS (Debian-based)
- **Emulation**: Docker BuildKit with ARM64 emulation 
- **Services**: All crooked-sentry services running in simulated Pi container
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
│  Docker Container: crooked-sentry-pi-sim                    │
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
- ✅ WireGuard VPN server
- ✅ ddclient DNS updates  
- ✅ dnsmasq local DNS
- ✅ Complete networking stack