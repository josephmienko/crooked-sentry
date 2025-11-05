# Home Assistant Role

This role deploys Home Assistant with Roku media player integration to the Raspberry Pi.

## Features

- Installs Home Assistant as a Docker container
- Configures Roku media player integration
- Proxies Home Assistant through nginx at `/homeassistant/` (LAN/VPN only)
- Integrates with Frigate for camera events

## Required Vault Variables

Add these to `ansible/inventory/group_vars/pi/vault.yml`:

```yaml
# Home Assistant
roku_ip: "192.168.0.220"  # Your Roku's IP address on LAN

# Optional: for external access
vault_external_url: "https://home.yourdomain.com"
vault_home_latitude: 37.7749
vault_home_longitude: -122.4194
```

## Finding Your Roku IP

On your Roku device:
1. Press Home button
2. Go to Settings → Network → About
3. Note the IP address

Or use network scanning:
```bash
# On your Mac/Linux
nmap -sn 192.168.0.0/24 | grep -B 2 "Roku"
```

## Deployment

Once vault variables are set:

```bash
# Deploy all roles including Home Assistant
make deploy

# Or deploy just Home Assistant
ansible-playbook ansible/site.yml --tags homeassistant
```

## Access

After deployment:

- **Local network**: http://192.168.0.200/homeassistant/
- **Via VPN**: http://192.168.0.200/homeassistant/ (through WireGuard)
- **Direct** (for setup): http://192.168.0.200:8123

## Roku Control

Once deployed, you can control your Roku via Home Assistant API:

```bash
# Get Roku state
curl http://192.168.0.200:8123/api/states/media_player.living_room_roku

# Launch Netflix
curl -X POST http://192.168.0.200:8123/api/services/media_player/select_source \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "media_player.living_room_roku", "source": "Netflix"}'
```

## Integration with Flutter App

Your Flutter dashboard can now control Roku through Home Assistant:

```dart
final homeAssistantUrl = 'http://192.168.0.200:8123';

// Get Roku state
final response = await http.get(
  Uri.parse('$homeAssistantUrl/api/states/media_player.living_room_roku')
);

// Launch app
await http.post(
  Uri.parse('$homeAssistantUrl/api/services/media_player/select_source'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'entity_id': 'media_player.living_room_roku',
    'source': 'Netflix'
  })
);
```

## Files Created

- `/opt/homeassistant/config/configuration.yaml` - Main HA config
- `/opt/homeassistant/config/roku.yaml` - Roku integration config
- Updated `/home/<pi-user>/docker-compose.yml` - Adds HA container (same compose the Docker role starts)
- Updated `/etc/nginx/conf.d/default.conf` - Adds `/homeassistant/` proxy

## Notes

- Home Assistant uses `network_mode: host` to discover devices on your LAN
- First startup may take 2-3 minutes to initialize
- Access the web UI at `:8123` to complete initial setup (create admin account)
- After initial setup, it will auto-discover the Roku if it's on the same network

### Sensi Thermostat

Sensi is typically added via the Home Assistant UI (no static YAML required):

1. Go to Settings → Devices & Services → Add Integration
2. Search for "Sensi" and follow the prompts
3. After pairing, you'll get a `climate.*` entity (e.g. `climate.sensi`)

No changes to Ansible config are needed for Sensi. The nginx proxy already exposes `/homeassistant/` to LAN/VPN clients, and the HA container runs on host network to discover local devices.
