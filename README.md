# Crooked Services (Infrastructure)

GitOps-style home automation infrastructure using Ansible for configuration management.

## What This Repo Contains

- **Ansible playbooks**: Raspberry Pi configuration and service deployment
- **Docker Compose**: Frigate NVR, Home Assistant, and supporting services
- **WireGuard VPN**: Secure remote access configuration
- **Nginx**: Reverse proxy with network-aware access control (LAN/VPN/Internet)

## Related Repositories

- **Dashboard UI**: [crooked-services-dashboard](https://github.com/josephmienko/crooked-services-dashboard) - Flutter web app for home automation

## Quick Start

### Prerequisites

- Raspberry Pi 4+ with Raspbian/Debian
- SSH access configured
- Ansible 2.9+ (installed via `make venv`)

### Initial Setup

1. **Install Ansible:**

   ```bash
   make venv
   ```

2. **Configure environment:**

   ```bash
   cp compose/.env.sample compose/.env
   # Edit compose/.env with your settings
   ```

3. **Initialize Pi and generate keys:**

   ```bash
   make init    # Sets up SSH and generates WireGuard keys
   make vault-add-keys  # Adds keys to Ansible vault
   ```

4. **Deploy:**

   ```bash
   make simulate  # Dry run
   make deploy    # Deploy to Pi
   ```

## Architecture

```asciidoc
┌─────────────────────────────────────────────┐
│    Raspberry Pi (192.168.0.200 - Static)    │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ Nginx (Reverse Proxy)                │   │
│  │ - Port 80/443                        │   │
│  │ - Serves dashboard (static files)    │   │
│  │ - Network-based access control       │   │
│  │ - Proxies /api/* to services         │   │
│  └─────────────────────────────────────┘   │
│           │                                 │
│           ├─ /             → Dashboard      │
│           ├─ /api/frigate  → Frigate:5000   │
│           └─ /api/ha       → HA:8123        │
│                                             │
│  ┌──────────────┐  ┌──────────────┐        │
│  │   Frigate    │  │ Home Assist. │        │
│  │  :5000       │  │  :8123       │        │
│  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────┘
```

### Static IP Configuration

The deployment automatically configures a **static IP address (192.168.0.200/24)** on the Raspberry Pi to prevent network connectivity issues from DHCP lease expiration. This ensures:

- ✅ Cameras can always reach the Pi at a known address
- ✅ No dependency on DHCP server availability
- ✅ Consistent remote access via SSH and WireGuard
- ✅ Reliable service availability

Configuration is managed via NetworkManager in `ansible/roles/common/tasks/main.yml`.

## Network Detection

Nginx classifies clients based on IP address:

- **LAN**: Local network clients (192.168.x.x, 172.16.x.x, etc.)
- **VPN**: WireGuard clients (10.8.0.x)
- **Internet**: All other clients (restricted access)

Configuration: `ansible/roles/nginx/templates/site.conf.j2`

## Secrets Management

Sensitive data is encrypted with Ansible Vault:

```bash
# Edit vault
make vault-edit

# Vault contains:
# - WireGuard keys
# - Camera credentials
# - DDNS tokens
```

## Testing

Simulation environment for testing before deploying to real hardware:

```bash
make sim-up       # Build and start simulation
make sim-deploy   # Test deployment
make sim-test     # Verify requirements
make sim-clean    # Clean up
```

## Health Checks

Verify all services are running correctly:

```bash
# Run health check against your Pi
./ops/health_check.sh 192.168.0.200

# Or use default IP from inventory
./ops/health_check.sh

# With SSH access for systemd service checks
export PI_SSH_USER=pi
ssh-copy-id pi@192.168.0.200
./ops/health_check.sh 192.168.0.200
```

The script validates:

- ✓ Network connectivity
- ✓ HTTP endpoints (root, /whoami, Frigate, Home Assistant)
- ✓ API responses and versions
- ✓ CORS configuration
- ✓ System services (via SSH: Docker, WireGuard, ddclient, dnsmasq)
- ✓ Running containers

## Maintenance

```bash
# Deploy specific roles
make deploy --tags nginx
make deploy --tags frigate

# Full deployment
make deploy
```

## Versioning

- Uses semantic versioning for infrastructure releases
- Independent from dashboard versioning
- Tag format: `v1.0.0`

## License

See [LICENSE](LICENSE)
