#!/usr/bin/env bash
# CrookedKeys Firewall Integration Script
# Configures enhanced security rules for the CrookedKeys system

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  print_error "This script must be run as root"
  exit 1
fi

print_status "Configuring CrookedKeys firewall rules..."

# Ensure UFW is installed and enabled
if ! command -v ufw >/dev/null 2>&1; then
  print_error "UFW not found. Installing..."
  apt-get update && apt-get install -y ufw
fi

# Basic UFW setup
print_status "Setting up basic UFW rules..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (be careful not to lock yourself out!)
ufw allow ssh comment "SSH access"

# Allow HTTP/HTTPS for web services
ufw allow 80/tcp comment "HTTP web services"
ufw allow 443/tcp comment "HTTPS web services"

# Allow WireGuard VPN
ufw allow 51820/udp comment "WireGuard VPN"

# Allow DNS (for dnsmasq if used)
ufw allow 53 comment "DNS server"

# Block direct access to sensitive services from internet
print_status "Blocking direct access to sensitive services..."

# Block direct Frigate access (force through nginx)
ufw deny 5000/tcp comment "Block direct Frigate access"

# Block direct Home Assistant access (force through nginx)  
ufw deny 8123/tcp comment "Block direct Home Assistant access"

# Block direct CrookedKeys API access (force through nginx)
ufw deny 3001/tcp comment "Block direct CrookedKeys API access"

# Allow LAN access to everything (trusted network)
LAN_CIDR="${LAN_CIDR:-192.168.0.0/24}"
print_status "Allowing full LAN access for $LAN_CIDR..."

ufw allow from "$LAN_CIDR" comment "Full LAN access"

# Allow Docker network access
print_status "Configuring Docker network rules..."
ufw allow from 172.16.0.0/12 comment "Docker bridge networks"
ufw allow from 172.20.0.0/24 comment "CrookedKeys Docker network"

# Configure WireGuard forwarding rules
VPN_CIDR="${VPN_CIDR:-10.8.0.0/24}"
VPN_INTERFACE="${VPN_INTERFACE:-wg0}"
WAN_INTERFACE="${WAN_INTERFACE:-eth0}"

print_status "Configuring VPN forwarding rules for $VPN_CIDR..."

# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

# Add VPN forwarding rules to UFW's before.rules
BEFORE_RULES="/etc/ufw/before.rules"

# Backup original rules
cp "$BEFORE_RULES" "$BEFORE_RULES.backup"

# Add WireGuard rules if not already present
if ! grep -q "# CrookedKeys WireGuard rules" "$BEFORE_RULES"; then
  print_status "Adding WireGuard NAT rules to UFW..."
  
  cat >> "$BEFORE_RULES" << EOF

# CrookedKeys WireGuard rules
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Forward VPN traffic to WAN
-A POSTROUTING -s $VPN_CIDR -o $WAN_INTERFACE -j MASQUERADE

COMMIT

# Filter table rules for WireGuard
*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]

# Allow VPN traffic forwarding
-A ufw-before-forward -i $VPN_INTERFACE -j ACCEPT
-A ufw-before-forward -o $VPN_INTERFACE -j ACCEPT

# Allow established connections
-A ufw-before-input -i $VPN_INTERFACE -m state --state ESTABLISHED,RELATED -j ACCEPT
-A ufw-before-output -o $VPN_INTERFACE -m state --state ESTABLISHED,RELATED -j ACCEPT

EOF
fi

# Configure advanced iptables rules for CrookedKeys
print_status "Setting up advanced security rules..."

# Create custom chain for CrookedKeys
iptables -t filter -N CROOKED_KEYS_FILTER 2>/dev/null || true
iptables -t filter -F CROOKED_KEYS_FILTER

# Rate limiting for API endpoints
iptables -A CROOKED_KEYS_FILTER -p tcp --dport 80 -m string --string "/api/crooked-keys/" --algo bm -m limit --limit 10/min --limit-burst 5 -j ACCEPT
iptables -A CROOKED_KEYS_FILTER -p tcp --dport 80 -m string --string "/api/crooked-keys/" --algo bm -j DROP

# Geographic blocking (block common attack sources - optional)
# Uncomment if you want to block specific countries
# iptables -A CROOKED_KEYS_FILTER -m geoip --src-cc CN,RU,KP -j DROP

# Insert the custom chain into INPUT
iptables -I INPUT -j CROOKED_KEYS_FILTER

# Save iptables rules
print_status "Saving iptables rules..."
if command -v iptables-save >/dev/null 2>&1; then
  iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

# Enable UFW
print_status "Enabling UFW..."
ufw --force enable

# Create monitoring script
print_status "Creating firewall monitoring script..."
cat > /usr/local/bin/monitor-crooked-keys-firewall.sh << 'EOF'
#!/bin/bash
# CrookedKeys Firewall Monitor

LOG_FILE="/var/log/crooked-keys-firewall.log"

# Log blocked connections
iptables -L -n -v | grep -E "(DROP|REJECT)" | while read line; do
  echo "$(date): BLOCKED: $line" >> "$LOG_FILE"
done

# Check for suspicious activity
recent_blocks=$(tail -100 "$LOG_FILE" | grep "$(date '+%Y-%m-%d')" | wc -l)
if [ "$recent_blocks" -gt 50 ]; then
  echo "$(date): WARNING: High number of blocked connections today ($recent_blocks)" >> "$LOG_FILE"
  # Optionally send alert
  # mail -s "CrookedKeys Security Alert" admin@example.com < "$LOG_FILE"
fi

# Rotate logs
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 10485760 ]; then
  mv "$LOG_FILE" "$LOG_FILE.old"
  touch "$LOG_FILE"
fi
EOF

chmod +x /usr/local/bin/monitor-crooked-keys-firewall.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/monitor-crooked-keys-firewall.sh") | crontab -

# Display status
print_status "Firewall configuration complete!"
echo
echo "Current UFW rules:"
ufw status numbered
echo
echo "Key security features enabled:"
echo "  ✓ Direct service access blocked from internet"
echo "  ✓ VPN and LAN traffic allowed"
echo "  ✓ Rate limiting for API endpoints"
echo "  ✓ WireGuard forwarding configured"
echo "  ✓ Monitoring and logging enabled"
echo
print_warning "IMPORTANT: Make sure you can still access your services!"
print_warning "Test all access methods before disconnecting from current session."
echo
echo "To test:"
echo "  - From internet: curl http://$(hostname -I | awk '{print $1}')/frigate/ (should be blocked)"
echo "  - From LAN: curl http://$(hostname -I | awk '{print $1}')/frigate/ (should work)"
echo "  - VPN: Connect via WireGuard first, then test"
EOF