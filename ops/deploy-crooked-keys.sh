#!/usr/bin/env bash
# CrookedKeys Integration Deployment Script
# Usage: ./ops/deploy-crooked-keys.sh [--dry-run] [--firewall-only] [--health-check-only]

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
  echo -e "\n${BLUE}================================${NC}"
  echo -e "${BLUE} $1 ${NC}"
  echo -e "${BLUE}================================${NC}"
}

print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
DRY_RUN=false
FIREWALL_ONLY=false
HEALTH_CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --firewall-only)
      FIREWALL_ONLY=true
      shift
      ;;
    --health-check-only)
      HEALTH_CHECK_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--dry-run] [--firewall-only] [--health-check-only]"
      exit 1
      ;;
  esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_header "CrookedKeys Integration Deployment"

# Health check only mode
if [ "$HEALTH_CHECK_ONLY" = true ]; then
  print_status "Running health check only..."
  exec "$SCRIPT_DIR/crooked-keys-health-check.sh"
fi

# Verify we're in the right directory
if [ ! -f "$PROJECT_DIR/ansible/site.yml" ]; then
  print_error "Cannot find ansible/site.yml. Please run from project root."
  exit 1
fi

# Check prerequisites
print_status "Checking prerequisites..."

# Check ansible
if ! command -v ansible-playbook >/dev/null 2>&1; then
  print_error "Ansible not found. Please install ansible first."
  exit 1
fi

# Check inventory file
INVENTORY_FILE="$PROJECT_DIR/ansible/inventory/hosts.ini"
if [ ! -f "$INVENTORY_FILE" ]; then
  print_error "Inventory file not found: $INVENTORY_FILE"
  exit 1
fi

# Extract Pi host info
PI_HOST=$(grep ansible_host "$INVENTORY_FILE" | cut -d'=' -f2 | awk '{print $1}')
if [ -z "$PI_HOST" ]; then
  print_error "Cannot determine Pi host from inventory"
  exit 1
fi

print_status "Target Pi: $PI_HOST"

# Test connectivity
print_status "Testing connectivity to Pi..."
if ! ping -c 1 -W 2 "$PI_HOST" >/dev/null 2>&1; then
  print_error "Cannot reach Pi at $PI_HOST"
  exit 1
fi

print_status "Pi is reachable ✓"

# Dry run mode
if [ "$DRY_RUN" = true ]; then
  print_warning "DRY RUN MODE - No actual changes will be made"
  ANSIBLE_FLAGS="--check --diff"
else
  ANSIBLE_FLAGS=""
fi

# Firewall-only mode  
if [ "$FIREWALL_ONLY" = true ]; then
  print_status "Deploying firewall configuration only..."
  
  if [ "$DRY_RUN" = false ]; then
    scp "$SCRIPT_DIR/setup-crooked-keys-firewall.sh" "bossbitch@$PI_HOST:/tmp/"
    ssh "bossbitch@$PI_HOST" "sudo bash /tmp/setup-crooked-keys-firewall.sh"
  else
    print_status "Would copy and run firewall setup script"
  fi
  
  print_status "Firewall deployment complete!"
  exit 0
fi

# Pre-deployment checks
print_header "Pre-deployment Validation"

print_status "Validating Ansible configuration..."
if ! ansible-playbook --syntax-check "$PROJECT_DIR/ansible/site.yml" >/dev/null 2>&1; then
  print_error "Ansible syntax check failed"
  exit 1
fi

print_status "Ansible syntax valid ✓"

# Check if CrookedKeys role exists
if [ ! -d "$PROJECT_DIR/ansible/roles/crooked-keys" ]; then
  print_error "CrookedKeys role not found. Integration files may be missing."
  exit 1
fi

print_status "CrookedKeys role found ✓"

# Backup existing configuration
print_status "Creating configuration backup..."
BACKUP_DIR="/tmp/crooked-services-backup-$(date +%Y%m%d_%H%M%S)"

if [ "$DRY_RUN" = false ]; then
  mkdir -p "$BACKUP_DIR"
  
  # Backup key files via SSH
  ssh "bossbitch@$PI_HOST" "sudo tar -czf /tmp/nginx-backup.tar.gz /etc/nginx/conf.d/ 2>/dev/null || true"
  scp "bossbitch@$PI_HOST:/tmp/nginx-backup.tar.gz" "$BACKUP_DIR/" 2>/dev/null || true
  
  print_status "Backup saved to: $BACKUP_DIR"
else
  print_status "Would create backup in: $BACKUP_DIR"
fi

# Main deployment
print_header "Deploying CrookedKeys Integration"

cd "$PROJECT_DIR"

print_status "Running Ansible playbook..."
if [ "$DRY_RUN" = true ]; then
  print_status "Dry run command:"
  echo "ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml $ANSIBLE_FLAGS"
fi

# Run the deployment
if ! ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml $ANSIBLE_FLAGS; then
  print_error "Ansible deployment failed!"
  
  if [ "$DRY_RUN" = false ]; then
    print_status "You can restore from backup: $BACKUP_DIR"
    print_status "To rollback: ssh bossbitch@$PI_HOST 'sudo systemctl stop crooked-keys'"
  fi
  
  exit 1
fi

if [ "$DRY_RUN" = false ]; then
  print_status "Ansible deployment completed ✓"
  
  # Post-deployment verification
  print_header "Post-deployment Verification"
  
  print_status "Waiting for services to start..."
  sleep 10
  
  print_status "Testing CrookedKeys API..."
  if curl -sf "http://$PI_HOST/api/crooked-keys/health" >/dev/null; then
    print_status "CrookedKeys API responding ✓"
  else
    print_warning "CrookedKeys API not responding yet (may need more time)"
  fi
  
  print_status "Testing service access control..."
  FRIGATE_TEST=$(curl -sf "http://$PI_HOST/frigate/" 2>/dev/null || echo "blocked")
  if echo "$FRIGATE_TEST" | grep -q "VPN connection"; then
    print_status "Frigate access control working ✓"
  else
    print_warning "Frigate access control may not be active"
  fi
  
  # Run full health check
  print_status "Running comprehensive health check..."
  if [ -f "$SCRIPT_DIR/crooked-keys-health-check.sh" ]; then
    "$SCRIPT_DIR/crooked-keys-health-check.sh" || print_warning "Health check reported some issues"
  fi
  
else
  print_status "Dry run completed - no changes made"
fi

# Summary
print_header "Deployment Summary"

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}DRY RUN COMPLETE${NC}"
  echo "No actual changes were made to your system."
  echo "Review the output above and run without --dry-run when ready."
else
  echo -e "${GREEN}DEPLOYMENT COMPLETE${NC}"
  echo "CrookedKeys integration has been deployed successfully!"
  echo
  echo "Next steps:"
  echo "1. Test access from different networks (LAN, VPN, Internet)"
  echo "2. Monitor logs: sudo tail -f /var/log/crooked-keys/crooked-keys.log"
  echo "3. Run health checks: ./ops/crooked-keys-health-check.sh"
  echo "4. Consider deploying firewall rules: ./ops/deploy-crooked-keys.sh --firewall-only"
  echo
  echo "Service URLs:"
  echo "  - Health Check: http://$PI_HOST/api/crooked-keys/health"
  echo "  - Network Info: http://$PI_HOST/whoami"
  echo "  - Frigate: http://$PI_HOST/frigate/ (VPN/LAN only)"
  echo "  - Home Assistant: http://$PI_HOST/homeassistant/ (VPN/LAN only)"
fi

echo
print_status "Deployment script completed successfully!"