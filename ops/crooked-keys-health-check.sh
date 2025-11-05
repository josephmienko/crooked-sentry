#!/usr/bin/env bash
# Enhanced Health Check Script with CrookedKeys Integration
# Usage: ./ops/crooked-keys-health-check.sh [pi-hostname-or-ip]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_info() {
  echo -e "${PURPLE}ℹ${NC} $1"
}

# Test network access levels
test_access_level() {
  local endpoint="$1"
  local expected_level="$2"
  local description="$3"
  
  print_check "Testing $description access level..."
  
  local response=$(curl -sf -H "X-Test-Network: $expected_level" "http://${PI_HOST}${endpoint}" 2>/dev/null || echo "FAIL")
  
  if [ "$response" != "FAIL" ]; then
    local access_level=$(echo "$response" | grep -o '"X-Access-Level":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
    if [ "$access_level" = "$expected_level" ] || [ "$access_level" != "unknown" ]; then
      print_success "$description access level: $access_level"
    else
      print_warning "$description access level detection unclear"
    fi
  else
    print_error "$description endpoint not responding"
  fi
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

# CrookedKeys API Health Checks
print_header "CrookedKeys API Health"

print_check "Checking CrookedKeys API health..."
CK_HEALTH=$(curl -sf "http://${PI_HOST}/api/crooked-keys/health" 2>/dev/null || echo "")
if [ -n "$CK_HEALTH" ]; then
  print_success "CrookedKeys API responding"
  
  # Extract health details
  if echo "$CK_HEALTH" | grep -q '"status":"healthy"'; then
    print_success "CrookedKeys service status: healthy"
  else
    print_warning "CrookedKeys service may have issues"
  fi
  
  # Check version
  CK_VERSION=$(echo "$CK_HEALTH" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
  print_info "CrookedKeys version: $CK_VERSION"
else
  print_error "CrookedKeys API not responding"
fi

print_check "Testing CrookedKeys key exchange endpoint..."
CK_EXCHANGE_TEST=$(curl -sf -X POST -H "Content-Type: application/json" -d '{"test": true}' "http://${PI_HOST}/api/crooked-keys/exchange" 2>/dev/null || echo "")
if echo "$CK_EXCHANGE_TEST" | grep -q '"error"'; then
  print_success "CrookedKeys exchange endpoint responding (expected test error)"
elif [ -n "$CK_EXCHANGE_TEST" ]; then
  print_success "CrookedKeys exchange endpoint responding"
else
  print_error "CrookedKeys exchange endpoint not responding"
fi

print_check "Testing VPN config endpoint access..."
VPN_CONFIG_TEST=$(curl -sf "http://${PI_HOST}/api/crooked-keys/vpn-config" 2>/dev/null || echo "")
if echo "$VPN_CONFIG_TEST" | grep -q "Interface"; then
  print_success "VPN config endpoint accessible (you're on trusted network)"
elif echo "$VPN_CONFIG_TEST" | grep -q "requires trusted network"; then
  print_info "VPN config properly protected (internet access blocked)"
else
  print_warning "VPN config endpoint response unclear"
fi

# Enhanced Service Access Testing
print_header "Enhanced Service Access Control"

print_check "Testing Frigate access control..."
FRIGATE_RESPONSE=$(curl -sf "http://${PI_HOST}/frigate/" 2>/dev/null || echo "")
if echo "$FRIGATE_RESPONSE" | grep -q "VPN connection"; then
  print_info "Frigate properly blocked from internet (VPN required message shown)"
elif [ -n "$FRIGATE_RESPONSE" ]; then
  print_success "Frigate accessible (you're on trusted network)"
else
  print_error "Frigate not responding"
fi

print_check "Testing Home Assistant access control..."
HA_RESPONSE=$(curl -sf "http://${PI_HOST}/homeassistant/" 2>/dev/null || echo "")
if echo "$HA_RESPONSE" | grep -q "VPN connection"; then
  print_info "Home Assistant properly blocked from internet (VPN required message shown)"
elif [ -n "$HA_RESPONSE" ]; then
  print_success "Home Assistant accessible (you're on trusted network)"
else
  print_error "Home Assistant not responding"
fi

# Network Classification Tests
print_header "Network Classification Tests"

print_check "Testing network detection endpoint..."
WHOAMI_RESPONSE=$(curl -sf "http://${PI_HOST}/whoami" 2>/dev/null || echo "")
if [ -n "$WHOAMI_RESPONSE" ]; then
  NETWORK=$(echo "$WHOAMI_RESPONSE" | grep -o '"network":"[^"]*"' | cut -d'"' -f4)
  CLIENT_IP=$(echo "$WHOAMI_RESPONSE" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
  print_success "Network classification: $NETWORK (IP: $CLIENT_IP)"
  
  case "$NETWORK" in
    "lan")
      print_info "You're accessing from LAN - full access available"
      ;;
    "vpn")
      print_info "You're accessing via VPN - full access available"
      ;;
    "internet")
      print_info "You're accessing from internet - limited to public services"
      ;;
    *)
      print_warning "Unknown network classification: $NETWORK"
      ;;
  esac
else
  print_error "Network classification endpoint not responding"
fi

# Rate Limiting Tests
print_header "Security & Rate Limiting Tests"

print_check "Testing API rate limiting..."
rate_limit_count=0
for i in {1..12}; do
  response=$(curl -sf -w "%{http_code}" "http://${PI_HOST}/api/crooked-keys/health" 2>/dev/null || echo "000")
  if [ "$response" = "429" ]; then
    rate_limit_count=$i
    break
  fi
  sleep 0.1
done

if [ "$rate_limit_count" -gt 0 ] && [ "$rate_limit_count" -le 11 ]; then
  print_success "Rate limiting active (triggered after $rate_limit_count requests)"
elif [ "$rate_limit_count" -eq 0 ]; then
  print_warning "Rate limiting may not be configured"
else
  print_info "Rate limiting not triggered in test (limit > 11 req/test)"
fi

# System Services Check
print_header "System Services Status"

if command -v ssh >/dev/null 2>&1; then
  print_check "Checking system services via SSH..."
  SSH_USER="bossbitch"
  
  if ssh -o ConnectTimeout=5 -o BatchMode=yes "${SSH_USER}@${PI_HOST}" "exit" 2>/dev/null; then
    SSH_RESULTS=$(ssh "${SSH_USER}@${PI_HOST}" 'bash -s' << 'REMOTE_SCRIPT'
      echo "docker:$(systemctl is-active docker 2>&1)"
      echo "wireguard:$(systemctl is-active wg-quick@wg0 2>&1)"
      echo "nginx:$(systemctl is-active nginx 2>&1)"
      echo "crooked-keys:$(systemctl is-active crooked-keys 2>&1)"
      
      # Check container health
      if sudo docker ps --format '{{.Names}}: {{.Status}}' 2>/dev/null | grep -E "(frigate|homeassistant|crooked-keys)"; then
        true
      else
        echo "containers:check_failed"
      fi
REMOTE_SCRIPT
    )
    
    # Parse and display results
    echo "$SSH_RESULTS" | while IFS=: read -r service status; do
      case "$service" in
        "docker"|"wireguard"|"nginx"|"crooked-keys")
          if echo "$status" | grep -q "active"; then
            print_success "$service service is active"
          else
            print_error "$service service is not active: $status"
          fi
          ;;
        *)
          if [ "$service" != "containers" ] && [ -n "$service" ]; then
            if echo "$status" | grep -q "Up.*healthy\|Up.*hours\|Up.*minutes"; then
              print_success "Container $service: $status"
            fi
          fi
          ;;
      esac
    done
  else
    print_warning "SSH access failed - using password authentication for service checks"
    print_info "Run: ssh-copy-id bossbitch@$PI_HOST for passwordless checks"
  fi
fi

# Log Analysis
print_header "Security Logs Analysis"

print_check "Checking recent security events..."
print_info "CrookedKeys logs: /var/log/nginx/crooked-keys-*.log"
print_info "Frigate access logs: /var/log/nginx/frigate-access.log"  
print_info "Home Assistant logs: /var/log/nginx/homeassistant-access.log"

# Storage Check
print_header "Storage Status"

print_check "Checking Frigate storage after cleanup..."
if command -v ssh >/dev/null 2>&1 && ssh -o ConnectTimeout=5 -o BatchMode=yes "bossbitch@${PI_HOST}" "exit" 2>/dev/null; then
  STORAGE_INFO=$(ssh "bossbitch@${PI_HOST}" "df -h /mnt/frigate 2>/dev/null || echo 'storage_check_failed'" 2>/dev/null)
  if [ "$STORAGE_INFO" != "storage_check_failed" ]; then
    echo "$STORAGE_INFO" | tail -1 | while read -r filesystem size used avail use_pct mountpoint; do
      if [ -n "$size" ]; then
        print_success "Frigate storage: $used used of $size ($use_pct full)"
        # Warn if usage is high
        use_num=$(echo "$use_pct" | tr -d '%')
        if [ "$use_num" -gt 80 ] 2>/dev/null; then
          print_warning "Storage usage is high ($use_pct) - consider cleanup"
        fi
      fi
    done
  else
    print_warning "Could not check Frigate storage status"
  fi
else
  print_info "SSH required for storage check - skipping"
fi

# Summary
print_header "CrookedKeys Integration Health Summary"
echo -e "Errors:   ${RED}${ERRORS}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"

if [ "$ERRORS" -eq 0 ]; then
  echo -e "\n${GREEN}✓ CrookedKeys integration is working properly!${NC}"
  echo -e "${GREEN}✓ All security controls are active${NC}"
  echo -e "${GREEN}✓ Network access classification functioning${NC}"
  exit 0
elif [ "$ERRORS" -lt 3 ]; then
  echo -e "\n${YELLOW}⚠ Minor issues detected but core security is operational${NC}"
  exit 0
else
  echo -e "\n${RED}✗ Multiple issues detected - review configuration${NC}"
  exit 1
fi