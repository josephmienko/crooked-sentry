#!/usr/bin/env bash
# CrookedKeys Integration Test Script
# Tests the integration between your Docker infrastructure and CrookedKeys API

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
  echo -e "\n${BLUE}===================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}===================================${NC}"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

# Configuration
PI_HOST="${1:-192.168.0.200}"
ERRORS=0
WARNINGS=0

print_header "CrookedKeys Integration Test Suite"
print_info "Testing Pi at: $PI_HOST"

# Test 1: Check if CrookedKeys API is running on host
print_header "Host System Tests"

print_info "Testing CrookedKeys API directly on host..."
if curl -sf --connect-timeout 5 "http://$PI_HOST:8443/health" >/dev/null 2>&1; then
  API_HEALTH=$(curl -s "http://$PI_HOST:8443/health")
  if echo "$API_HEALTH" | jq -e '.status' >/dev/null 2>&1; then
    STATUS=$(echo "$API_HEALTH" | jq -r '.status')
    print_success "CrookedKeys API responding on host: status=$STATUS"
  else
    print_success "CrookedKeys API responding on host (non-JSON response)"
  fi
else
  print_error "CrookedKeys API not accessible on host port 8443"
  ((ERRORS++))
fi

print_info "Testing WireGuard VPN service..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "bossbitch@$PI_HOST" "sudo systemctl is-active wg-quick@wg0" 2>/dev/null | grep -q "active"; then
  print_success "WireGuard VPN service is active"
else
  print_warning "WireGuard VPN service may not be active"
  ((WARNINGS++))
fi

# Test 2: Check Docker containers
print_header "Docker Infrastructure Tests"

print_info "Testing Docker containers status..."
CONTAINERS=$(ssh -o ConnectTimeout=5 "bossbitch@$PI_HOST" "sudo docker ps --format '{{.Names}}: {{.Status}}'" 2>/dev/null || echo "docker_check_failed")

if [ "$CONTAINERS" != "docker_check_failed" ]; then
  echo "$CONTAINERS" | while IFS=: read -r name status; do
    if [ -n "$name" ] && [ -n "$status" ]; then
      if echo "$status" | grep -q "Up"; then
        print_success "Container $name: $status"
      else
        print_warning "Container $name: $status"
      fi
    fi
  done
else
  print_warning "Could not check Docker container status"
  ((WARNINGS++))
fi

print_info "Testing nginx container can reach host..."
NGINX_HOST_TEST=$(ssh -o ConnectTimeout=5 "bossbitch@$PI_HOST" "sudo docker exec reverse-proxy curl -sf --connect-timeout 3 http://host.docker.internal:8443/health 2>/dev/null || echo 'FAILED'" 2>/dev/null)

if [ "$NGINX_HOST_TEST" != "FAILED" ] && [ -n "$NGINX_HOST_TEST" ]; then
  print_success "nginx container can reach CrookedKeys API on host"
else
  print_error "nginx container cannot reach CrookedKeys API on host"
  print_info "This may require updating Docker Compose configuration"
  ((ERRORS++))
fi

# Test 3: nginx Configuration Tests
print_header "nginx Integration Tests"

print_info "Testing CrookedKeys API via nginx proxy..."
if curl -sf --connect-timeout 5 "http://$PI_HOST/api/crooked-keys/health" >/dev/null 2>&1; then
  PROXY_HEALTH=$(curl -s "http://$PI_HOST/api/crooked-keys/health")
  if [ -n "$PROXY_HEALTH" ]; then
    print_success "CrookedKeys API accessible via nginx proxy"
    if echo "$PROXY_HEALTH" | jq -e '.status' >/dev/null 2>&1; then
      print_info "API Health: $(echo "$PROXY_HEALTH" | jq -r '.status // "unknown"')"
    fi
  else
    print_warning "CrookedKeys API proxy returns empty response"
    ((WARNINGS++))
  fi
else
  print_error "CrookedKeys API not accessible via nginx proxy"
  print_info "Check nginx configuration and restart containers"
  ((ERRORS++))
fi

print_info "Testing existing services still work..."
if curl -sf --connect-timeout 5 "http://$PI_HOST/frigate/" >/dev/null 2>&1; then
  print_success "Frigate still accessible via nginx"
elif curl -sf --connect-timeout 5 "http://$PI_HOST/frigate/" 2>&1 | grep -q "403\|VPN"; then
  print_success "Frigate properly protected (403/VPN required)"
else
  print_warning "Frigate access test inconclusive"
  ((WARNINGS++))
fi

if curl -sf --connect-timeout 5 "http://$PI_HOST/homeassistant/" >/dev/null 2>&1; then
  print_success "Home Assistant still accessible via nginx"
elif curl -sf --connect-timeout 5 "http://$PI_HOST/homeassistant/" 2>&1 | grep -q "403\|VPN"; then
  print_success "Home Assistant properly protected (403/VPN required)"
else
  print_warning "Home Assistant access test inconclusive"
  ((WARNINGS++))
fi

# Test 4: Network Classification
print_header "Network Classification Tests"

print_info "Testing network detection endpoint..."
WHOAMI_RESPONSE=$(curl -s "http://$PI_HOST/whoami" 2>/dev/null || echo "")
if [ -n "$WHOAMI_RESPONSE" ]; then
  NETWORK=$(echo "$WHOAMI_RESPONSE" | jq -r '.network // "unknown"' 2>/dev/null || echo "parse_error")
  CLIENT_IP=$(echo "$WHOAMI_RESPONSE" | jq -r '.ip // "unknown"' 2>/dev/null || echo "parse_error")
  
  if [ "$NETWORK" != "unknown" ] && [ "$NETWORK" != "parse_error" ]; then
    print_success "Network classification: $NETWORK (IP: $CLIENT_IP)"
    
    case "$NETWORK" in
      "lan")
        print_info "✓ Detected as LAN access - full services available"
        ;;
      "internet")
        print_info "ℹ Detected as Internet access - limited to public services"
        ;;
      *)
        print_warning "Unknown network classification: $NETWORK"
        ((WARNINGS++))
        ;;
    esac
  else
    print_warning "Could not parse network classification response"
    ((WARNINGS++))
  fi
else
  print_error "Network classification endpoint not responding"
  ((ERRORS++))
fi

# Test 5: CORS and API Response Headers
print_header "API Response & CORS Tests"

print_info "Testing CORS headers on CrookedKeys API..."
CORS_HEADERS=$(curl -s -I -X OPTIONS -H "Origin: https://localhost:3000" "http://$PI_HOST/api/crooked-keys/health" 2>/dev/null | grep -i "access-control" || echo "")
if [ -n "$CORS_HEADERS" ]; then
  print_success "CORS headers present on CrookedKeys API"
else
  print_warning "CORS headers may not be configured"
  ((WARNINGS++))
fi

print_info "Testing API response format..."
API_RESPONSE=$(curl -s "http://$PI_HOST/api/crooked-keys/health" 2>/dev/null || echo "")
if echo "$API_RESPONSE" | jq -e '.' >/dev/null 2>&1; then
  print_success "API returns valid JSON"
  if echo "$API_RESPONSE" | jq -e '.timestamp' >/dev/null 2>&1; then
    TIMESTAMP=$(echo "$API_RESPONSE" | jq -r '.timestamp')
    print_info "API timestamp: $TIMESTAMP"
  fi
else
  print_warning "API response is not valid JSON: $API_RESPONSE"
  ((WARNINGS++))
fi

# Test 6: iOS App Integration Preparation
print_header "iOS App Integration Readiness"

print_info "Testing HTTPS readiness..."
if curl -k -sf --connect-timeout 5 "https://$PI_HOST/whoami" >/dev/null 2>&1; then
  print_success "HTTPS endpoint accessible (SSL may be self-signed)"
elif curl -sf --connect-timeout 5 "http://$PI_HOST/whoami" >/dev/null 2>&1; then
  print_warning "Only HTTP available - iOS apps prefer HTTPS"
  ((WARNINGS++))
else
  print_error "Neither HTTP nor HTTPS endpoints accessible"
  ((ERRORS++))
fi

print_info "Testing domain resolution..."
DOMAIN_IP=$(nslookup "cameras.crookedsentry.net" 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "")
if [ "$DOMAIN_IP" = "$PI_HOST" ]; then
  print_success "Domain resolves to Pi: cameras.crookedsentry.net → $DOMAIN_IP"
elif [ -n "$DOMAIN_IP" ]; then
  print_warning "Domain resolves to different IP: cameras.crookedsentry.net → $DOMAIN_IP"
  ((WARNINGS++))
else
  print_warning "Domain resolution test inconclusive"
  ((WARNINGS++))
fi

# Summary and Recommendations
print_header "Integration Test Summary"

echo -e "Errors:   ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo -e "\n${GREEN}🎉 Perfect! CrookedKeys integration is working flawlessly!${NC}"
  echo -e "${GREEN}✓ All tests passed - ready for iOS app deployment${NC}"
elif [ "$ERRORS" -eq 0 ]; then
  echo -e "\n${YELLOW}✓ CrookedKeys integration is working with minor issues${NC}"
  echo -e "${YELLOW}⚠ Check warnings above, but core functionality is ready${NC}"
else
  echo -e "\n${RED}❌ CrookedKeys integration has issues that need fixing${NC}"
  echo -e "${RED}✗ Review errors above before deploying iOS app${NC}"
fi

echo ""
print_info "Next steps:"
if [ "$ERRORS" -gt 0 ]; then
  echo "  1. Fix the errors shown above"
  echo "  2. Restart Docker containers: docker-compose down && docker-compose up -d"
  echo "  3. Re-run this test: $0"
elif [ "$WARNINGS" -gt 0 ]; then
  echo "  1. Review warnings (optional fixes)"
  echo "  2. Deploy iOS app with CrookedKeys integration"
  echo "  3. Test end-to-end: iOS app → admin password → VPN → cameras"
else
  echo "  1. Deploy iOS app with CrookedKeys integration" 
  echo "  2. Configure router port forwarding: 51820/UDP → $PI_HOST:51820"
  echo "  3. Test remote access: iOS app → admin password → VPN → cameras"
fi

echo ""
print_info "Useful commands:"
echo "  - Restart containers: ssh bossbitch@$PI_HOST 'cd /path/to/compose && sudo docker-compose restart'"
echo "  - Check API logs: ssh bossbitch@$PI_HOST 'sudo journalctl -u crooked-keys-api -f'"
echo "  - Check nginx logs: ssh bossbitch@$PI_HOST 'sudo docker logs reverse-proxy -f'"
echo "  - Test health: curl -s http://$PI_HOST/api/crooked-keys/health | jq"

exit $ERRORS