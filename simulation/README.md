# Crooked Sentry Simulation Environment

This directory contains Docker-based simulation of the Raspberry Pi environment
for testing the complete crooked-sentry architecture locally.

## Architecture

- **Base Image**: ARM64 Raspberry Pi OS (Debian-based)
- **Emulation**: Docker BuildKit with ARM64 emulation 
- **Services**: All crooked-sentry services running in simulated Pi container
- **Testing**: Full end-to-end verification without physical hardware

## Usage

```bash
# Build and run simulation
make simulate

# Test all three requirements
make test-simulation

# Clean up
make clean-simulation
```

## Components Simulated

- ✅ Docker CE ARM64 installation
- ✅ nginx reverse proxy with geo-routing
- ✅ Frigate camera system
- ✅ WireGuard VPN server
- ✅ ddclient DNS updates  
- ✅ dnsmasq local DNS
- ✅ Complete networking stack