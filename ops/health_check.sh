#!/usr/bin/env bash
# Health check script for crooked-services Pi services
# Usage: ./ops/health_check.sh [pi-hostname-or-ip]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default target
PI_HOST="${1:-192.168.0.200}"
ERRORS=0
WARNINGS=0

# Helper functions
print_header() {
  echo -e "\n${BLUE}===================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}===================================${NC}"
}

print_check() {
  echo -e "${YELLOW}→${NC} $1"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
  ((ERRORS++))
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
  ((WARNINGS++))
}

# Check if host is reachable
print_header "Connectivity Check"
print_check "Pinging $PI_HOST..."
if ping -c 1 -W 2 "$PI_HOST" > /dev/null 2>&1; then
  print_success "Pi is reachable at $PI_HOST"
else
  print_error "Cannot reach Pi at $PI_HOST"
  exit 1
fi

# Check HTTP endpoints
print_header "HTTP Endpoints"

# Root endpoint (info page)
print_check "Checking root endpoint..."
if curl -sf "http://${PI_HOST}/" > /dev/null; then
  print_success "Root endpoint (/) responding"
else
  print_error "Root endpoint (/) not responding"
fi

# /whoami endpoint
print_check "Checking /whoami endpoint..."
WHOAMI_RESPONSE=$(curl -sf "http://${PI_HOST}/whoami" 2>/dev/null || echo "")
if [ -n "$WHOAMI_RESPONSE" ]; then
  NETWORK=$(echo "$WHOAMI_RESPONSE" | grep -o '"network":"[^"]*"' | cut -d'"' -f4)
  CLIENT_IP=$(echo "$WHOAMI_RESPONSE" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
  print_success "/whoami responding: network=$NETWORK, ip=$CLIENT_IP"
else
  print_error "/whoami not responding"
fi

# Frigate API
print_check "Checking Frigate API..."
FRIGATE_VERSION=$(curl -sf "http://${PI_HOST}/frigate/api/version" 2>/dev/null || echo "")
if [ -n "$FRIGATE_VERSION" ]; then
  print_success "Frigate API responding: version $FRIGATE_VERSION"
else
  print_error "Frigate API (/frigate/api/version) not responding"
fi

print_check "Checking Frigate config..."
FRIGATE_CONFIG=$(curl -sf "http://${PI_HOST}/frigate/api/config" 2>/dev/null || echo "")
if echo "$FRIGATE_CONFIG" | grep -q '"cameras"'; then
  CAM_COUNT=$(echo "$FRIGATE_CONFIG" | grep -o '"[^"]*":{' | wc -l | tr -d ' ')
  print_success "Frigate config valid: $CAM_COUNT cameras configured"
else
  print_warning "Frigate config returned but no cameras found"
fi

print_check "Checking Frigate stats..."
FRIGATE_STATS=$(curl -sf "http://${PI_HOST}/frigate/api/stats" 2>/dev/null || echo "")
if [ -n "$FRIGATE_STATS" ]; then
  print_success "Frigate stats responding"
else
  print_warning "Frigate stats endpoint not responding"
fi

# Home Assistant API
print_check "Checking Home Assistant API..."
HA_API_RESPONSE=$(curl -sf "http://${PI_HOST}/homeassistant/api/" 2>/dev/null || echo "")
if echo "$HA_API_RESPONSE" | grep -q "API running"; then
  print_success "Home Assistant API responding"
else
  print_error "Home Assistant API (/homeassistant/api/) not responding"
fi

print_check "Checking Home Assistant config..."
HA_CONFIG=$(curl -sf "http://${PI_HOST}/homeassistant/api/config" 2>/dev/null || echo "")
if echo "$HA_CONFIG" | grep -q '"location_name"'; then
  HA_VERSION=$(echo "$HA_CONFIG" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
  print_success "Home Assistant config valid: version $HA_VERSION"
else
  print_warning "Home Assistant config endpoint returned unexpected data"
fi

# CORS checks
print_header "CORS Configuration"

print_check "Testing CORS on /whoami..."
CORS_WHOAMI=$(curl -sf -X OPTIONS -H "Origin: http://localhost:3000" -I "http://${PI_HOST}/whoami" 2>/dev/null | grep -i "access-control-allow-origin" || echo "")
if [ -n "$CORS_WHOAMI" ]; then
  print_success "/whoami CORS headers present"
else
  print_warning "/whoami missing CORS headers"
fi

print_check "Testing CORS on Frigate..."
CORS_FRIGATE=$(curl -sf -X OPTIONS -H "Origin: http://localhost:3000" -I "http://${PI_HOST}/frigate/api/version" 2>/dev/null | grep -i "access-control-allow-origin" || echo "")
if [ -n "$CORS_FRIGATE" ]; then
  print_success "Frigate CORS headers present"
else
  print_warning "Frigate missing CORS headers"
fi

print_check "Testing CORS on Home Assistant..."
CORS_HA=$(curl -sf -X OPTIONS -H "Origin: http://localhost:3000" -I "http://${PI_HOST}/homeassistant/api/" 2>/dev/null | grep -i "access-control-allow-origin" || echo "")
if [ -n "$CORS_HA" ]; then
  print_success "Home Assistant CORS headers present"
else
  print_warning "Home Assistant missing CORS headers"
fi

# SSH connectivity (for systemd checks)
print_header "System Services (via SSH)"

# Try to SSH and check systemd services
print_check "Attempting SSH connection to check services..."
SSH_USER="${PI_USER}"

# Try key-based auth first, then fall back to password
SSH_SUCCESS=false
if ssh -o ConnectTimeout=5 -o BatchMode=yes "${SSH_USER}@${PI_HOST}" "exit" 2>/dev/null; then
  SSH_SUCCESS=true
  print_success "SSH connection successful (key-based auth)"
  AUTH_METHOD="key"
else
  # Try password auth (interactive)
  print_check "Key-based auth failed, trying password authentication..."
  if ssh -o ConnectTimeout=5 "${SSH_USER}@${PI_HOST}" "exit"; then
    SSH_SUCCESS=true
    print_success "SSH connection successful (password auth)"
    AUTH_METHOD="password"
  fi
fi

if [ "$SSH_SUCCESS" = true ]; then
  # Run all checks in a single SSH session
  print_check "Running all system checks in one session..."
  
  # Execute remote script that performs all checks
  SSH_RESULTS=$(ssh "${SSH_USER}@${PI_HOST}" 'bash -s' << 'REMOTE_SCRIPT'
    # Check Docker
    echo "docker:$(systemctl is-active docker 2>&1)"
    
    # Check WireGuard
    echo "wireguard:$(systemctl is-active wg-quick@wg0 2>&1)"
    
    # Check ddclient
    echo "ddclient:$(systemctl is-active ddclient 2>&1)"
    
    # Check dnsmasq
    echo "dnsmasq:$(systemctl is-active dnsmasq 2>&1)"
    
    # Check Docker containers (use sudo if needed, suppress errors)
    if command -v docker &> /dev/null; then
      if docker ps --format '{{.Names}}: {{.Status}}' 2>/dev/null; then
        true
      elif sudo docker ps --format '{{.Names}}: {{.Status}}' 2>/dev/null; then
        true
      else
        echo "containers:permission_denied"
      fi
    else
      echo "containers:docker_not_installed"
    fi
REMOTE_SCRIPT
  )
  
  # Parse results
  print_check "Checking Docker service..."
  if echo "$SSH_RESULTS" | grep "^docker:" | grep -q "active"; then
    print_success "Docker service is active"
  else
    print_error "Docker service is not active"
  fi
  
  print_check "Checking WireGuard service..."
  if echo "$SSH_RESULTS" | grep "^wireguard:" | grep -q "active"; then
    print_success "WireGuard service is active"
  else
    print_warning "WireGuard service is not active"
  fi
  
  print_check "Checking ddclient service..."
  if echo "$SSH_RESULTS" | grep "^ddclient:" | grep -q "active"; then
    print_success "ddclient service is active"
  else
    print_warning "ddclient service is not active"
  fi
  
  print_check "Checking dnsmasq service..."
  if echo "$SSH_RESULTS" | grep "^dnsmasq:" | grep -q "active"; then
    print_success "dnsmasq service is active"
  else
    print_warning "dnsmasq service is not active"
  fi
  
  print_check "Checking Docker containers..."
  CONTAINERS=$(echo "$SSH_RESULTS" | grep -v "^docker:\|^wireguard:\|^ddclient:\|^dnsmasq:\|^containers:")
  if [ -n "$CONTAINERS" ] && [ "$CONTAINERS" != "" ]; then
    echo "$CONTAINERS" | while IFS= read -r line; do
      if [ -n "$line" ]; then
        print_success "Container $line"
      fi
    done
  else
    if echo "$SSH_RESULTS" | grep -q "permission_denied"; then
      print_warning "Docker containers check failed (permission denied)"
    elif echo "$SSH_RESULTS" | grep -q "docker_not_installed"; then
      print_warning "Docker not installed"
    else
      print_warning "No running Docker containers found"
    fi
  fi
  
else
  print_warning "SSH authentication failed - skipping systemd checks"
  echo "  To enable systemd checks, set up SSH access:"
  echo "  export PI_USER=your-username"
  echo "  ssh-copy-id \${PI_USER}@${PI_HOST}  # (optional, for passwordless auth)"
fi

# DNS check (if dnsmasq is running)
print_header "DNS Configuration"
print_check "Checking if dnsmasq is listening on port 53..."
if nc -zv -w 2 "$PI_HOST" 53 2>&1 | grep -q "succeeded\|open"; then
  print_success "dnsmasq is listening on port 53"
else
  print_warning "dnsmasq not reachable on port 53 (may be firewalled)"
fi

# WireGuard check
print_header "WireGuard VPN"
print_check "Checking WireGuard config endpoint..."
WG_CONFIG=$(curl -sf "http://${PI_HOST}/household.conf" 2>/dev/null || echo "")
if echo "$WG_CONFIG" | grep -q "\[Interface\]"; then
  print_success "WireGuard config accessible at /household.conf"
else
  print_warning "WireGuard config not accessible (may require LAN/VPN access)"
fi

# Summary
print_header "Health Check Summary"
echo -e "Errors:   ${RED}${ERRORS}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"

if [ "$ERRORS" -eq 0 ]; then
  echo -e "\n${GREEN}✓ All critical checks passed!${NC}"
  exit 0
elif [ "$ERRORS" -lt 3 ]; then
  echo -e "\n${YELLOW}⚠ Some issues detected but system is mostly operational${NC}"
  exit 0
else
  echo -e "\n${RED}✗ Multiple critical issues detected${NC}"
  exit 1
fi
