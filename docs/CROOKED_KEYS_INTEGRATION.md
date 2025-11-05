# CrookedKeys Integration Guide

## 🔐 Overview

This integration adds the CrookedKeys secure key exchange system to your existing Raspberry Pi infrastructure, providing enhanced VPN-based access control while maintaining compatibility with your current setup.

## 🏗️ Architecture

```
Internet Users
    ↓ (blocked from sensitive services)
[nginx reverse proxy with CrookedKeys integration]
    ↓ 
┌─ Public Services (allowed)
│  ├── Info page (/)
│  ├── /whoami endpoint  
│  └── CrookedKeys API (/api/crooked-keys/)
│
├─ Protected Services (VPN/LAN only) 
│  ├── Frigate (/frigate/)
│  ├── Home Assistant (/homeassistant/)
│  └── WireGuard config (/wireguard/)
│
└─ Security Layer
   ├── Rate limiting
   ├── Network classification  
   ├── Access logging
   └── Intrusion detection
```

## 📋 Integration Components

### 1. **CrookedKeys Service Role** 
- **Location**: `ansible/roles/crooked-keys/`
- **Purpose**: Deploys the CrookedKeys API service
- **Runs on**: Port 3001 (internal), exposed via nginx

### 2. **Enhanced nginx Configuration**
- **File**: `ansible/roles/nginx/templates/crooked-keys-integration.conf.j2`
- **Features**:
  - Rate limiting for API endpoints
  - Enhanced security headers
  - Improved error messages with VPN setup links
  - Access level classification

### 3. **Firewall Integration**
- **Script**: `ops/setup-crooked-keys-firewall.sh`
- **Purpose**: Configures UFW rules to block direct service access
- **Features**: VPN forwarding, rate limiting, monitoring

### 4. **Enhanced Health Monitoring**
- **Script**: `ops/crooked-keys-health-check.sh`
- **Tests**: All CrookedKeys components, security controls, access levels

## 🚀 Deployment Instructions

### Step 1: Update Configuration

Add CrookedKeys variables to your environment or group vars:

```yaml
# ansible/inventory/group_vars/pi/vars.yml
crooked_keys_admin_password: "your-secure-admin-password"
crooked_keys_api_secret: "your-api-secret-key"
```

### Step 2: Deploy with Ansible

```bash
cd /Users/mienko/crooked-services
ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml
```

### Step 3: Configure Firewall (Optional but Recommended)

```bash
# SSH to your Pi
ssh bossbitch@192.168.0.200

# Run firewall setup
sudo /path/to/setup-crooked-keys-firewall.sh
```

### Step 4: Verify Integration

```bash
# Run enhanced health check
./ops/crooked-keys-health-check.sh
```

## 🔧 Configuration Options

### Service Configuration

Edit `ansible/roles/crooked-keys/defaults/main.yml`:

```yaml
# API Configuration
crooked_keys_port: 3001
crooked_keys_rate_limit_requests: 10
crooked_keys_rate_limit_window: 60

# Security Configuration  
crooked_keys_session_timeout: 3600
crooked_keys_max_active_keys: 100

# Integration Toggles
crooked_keys_frigate_enabled: true
crooked_keys_homeassistant_enabled: true
crooked_keys_nginx_integration: true
```

### Network Configuration

The system inherits your existing network settings:

```yaml
# Uses existing WireGuard configuration
vpn_network: "{{ wireguard_network }}"        # 10.8.0.0/24
vpn_server: "{{ wireguard_server_address }}"  # 10.8.0.1/24

# Uses existing LAN settings  
lan_cidrs: "{{ nginx_lan_cidrs }}"             # 192.168.0.0/24
```

## 🔒 Security Features

### 1. **Network Access Control**
- **Internet Users**: Can only access public info page and CrookedKeys API
- **LAN Users**: Full access to all services
- **VPN Users**: Full access to all services  
- **Admin Users**: Enhanced access with additional security context

### 2. **Rate Limiting**
- **API Endpoints**: 10 requests/minute per IP
- **Key Exchange**: 5 requests/minute per IP  
- **Service Access**: 20-30 requests/minute per IP

### 3. **Enhanced Logging**
- **Access Logs**: Separate logs for each service
- **Security Events**: Detailed logging of blocked attempts
- **Health Monitoring**: Automatic service health checks

### 4. **Error Handling**
- **Helpful Messages**: Internet users get VPN setup instructions
- **Status Codes**: Proper HTTP codes for different access scenarios
- **Debug Headers**: Network classification visible in responses

## 📊 Monitoring & Maintenance

### Health Checks

```bash
# Basic health check (existing)
./ops/health_check.sh

# Enhanced CrookedKeys health check  
./ops/crooked-keys-health-check.sh

# Quick API test
curl -s http://192.168.0.200/api/crooked-keys/health | jq
```

### Log Monitoring

```bash
# CrookedKeys API logs
sudo tail -f /var/log/nginx/crooked-keys-access.log

# Service access logs
sudo tail -f /var/log/nginx/frigate-access.log
sudo tail -f /var/log/nginx/homeassistant-access.log

# Service logs  
sudo docker logs crooked-keys -f
```

### Performance Monitoring

```bash
# Check service status
sudo systemctl status crooked-keys
sudo docker ps | grep crooked-keys

# Monitor resource usage
sudo docker stats crooked-keys
```

## 🧪 Testing Scenarios

### 1. **Internet Access Test**
```bash
# Should be blocked with helpful error
curl -s http://your-pi-ip/frigate/ | jq

# Should work  
curl -s http://your-pi-ip/whoami | jq
curl -s http://your-pi-ip/api/crooked-keys/health | jq
```

### 2. **VPN Access Test**  
```bash
# Connect to VPN first
sudo wg-quick up wg0

# Should work after VPN connection
curl -s http://10.8.0.1/frigate/
curl -s http://10.8.0.1/homeassistant/
```

### 3. **LAN Access Test**
```bash
# From LAN device (should work)
curl -s http://192.168.0.200/frigate/
curl -s http://192.168.0.200/homeassistant/
```

## 🔄 Integration with Existing Services

### Frigate Integration
- **Access Control**: VPN/LAN only with helpful error messages
- **CORS**: Enhanced to include VPN network ranges  
- **Logging**: Separate access log for security monitoring
- **Performance**: No impact on existing functionality

### Home Assistant Integration  
- **Access Control**: VPN/LAN only with setup guidance
- **WebSocket**: Full support for real-time features
- **Authentication**: Works with existing HA authentication
- **Dashboard**: Compatible with your iOS dashboard app

### WireGuard Integration
- **Configuration**: Uses existing WireGuard setup
- **Client Configs**: Enhanced with CrookedKeys metadata
- **Routing**: No changes to existing VPN routing
- **Performance**: No additional overhead

## 📱 Client Integration

### iOS Dashboard App

Your existing iOS dashboard will work unchanged. The app connects via:

1. **LAN Access**: Direct connection when on home network
2. **VPN Access**: Automatic VPN connection for remote access
3. **Network Detection**: App can check network status via `/whoami`

### Web Browsers

- **Internet Users**: See informative landing page with VPN setup links
- **LAN/VPN Users**: Direct access to services as before
- **Network Status**: Visible in browser developer tools via response headers

## 🚨 Troubleshooting

### Common Issues

**CrookedKeys API not responding:**
```bash
sudo systemctl status crooked-keys
sudo docker logs crooked-keys
sudo netstat -tulpn | grep 3001
```

**Services blocked unexpectedly:**
```bash
# Check network classification
curl -s http://your-pi-ip/whoami

# Check nginx config
sudo nginx -t
sudo systemctl status nginx
```

**VPN issues:**
```bash
sudo wg show
sudo systemctl status wg-quick@wg0
```

### Reset Integration

If you need to reset the CrookedKeys integration:

```bash
# Stop services
sudo systemctl stop crooked-keys
sudo docker compose -f /opt/crooked-keys/config/docker-compose.yml down

# Remove integration  
sudo rm -f /etc/nginx/conf.d/crooked-keys-integration.conf
sudo nginx -s reload

# Redeploy
ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml --tags crooked-keys
```

## 📞 Support

- **Health Check**: Run `./ops/crooked-keys-health-check.sh` for comprehensive status
- **Logs**: Check `/var/log/crooked-keys/` and nginx logs
- **Configuration**: All config in `/opt/crooked-keys/config/`  
- **Backup**: Daily backups to `/opt/crooked-keys/backups/`

## 🔮 Future Enhancements

Planned improvements:

- **HTTPS/TLS**: SSL certificate automation
- **2FA Integration**: Multi-factor authentication for admin access
- **Geographic Filtering**: Block requests from specific countries
- **Advanced Analytics**: Detailed access pattern analysis
- **Mobile App**: Dedicated CrookedKeys management app

---

The CrookedKeys integration provides enterprise-grade security while maintaining the simplicity and reliability of your existing infrastructure. All existing functionality continues to work unchanged while adding powerful new security capabilities.