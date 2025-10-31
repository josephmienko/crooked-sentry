#!/bin/bash
# Comprehensive test script for simulation environment

echo "=== CROOKED-SENTRY SIMULATION TEST ==="
echo ""

# Test Pi simulation connectivity
echo "🔌 Testing Pi simulation connectivity..."
if docker exec crooked-sentry-pi-sim echo "Pi simulation online" 2>/dev/null; then
    echo "✅ Pi simulation container is running"
else
    echo "❌ Pi simulation container not found or not running"
    exit 1
fi

# Test Docker-in-Docker  
echo ""
echo "🐳 Testing Docker-in-Docker..."
if docker exec crooked-sentry-pi-sim docker --version 2>/dev/null; then
    echo "✅ Docker available inside simulation"
else
    echo "❌ Docker not available inside simulation"
fi

# Test services inside container
echo ""
echo "🔧 Testing services inside Pi simulation..."
services=("sshd" "dockerd")
for service in "${services[@]}"; do
    if docker exec crooked-sentry-pi-sim pgrep -f "$service" > /dev/null 2>&1; then
        echo "✅ $service is running"
    else
        echo "⚠️  $service may not be running"
    fi
done

echo ""
echo "🌐 Testing HTTP endpoints..."

# Test from host (should be trusted - LAN simulation)
echo "Testing from host (localhost:8080)..."
if response=$(curl -s -I http://localhost:8080/ 2>/dev/null); then
    status=$(echo "$response" | head -1 | awk '{print $2}')
    echo "   Status: $status"
    if [[ "$status" == "200" ]]; then
        echo "✅ Host access works"
    else
        echo "⚠️  Host access returned $status (expected 200)"
    fi
else
    echo "❌ Cannot connect to http://localhost:8080/"
fi

# Test household config access
echo ""
echo "Testing household.conf access..."
if response=$(curl -s -I http://localhost:8080/household.conf 2>/dev/null); then
    status=$(echo "$response" | head -1 | awk '{print $2}')
    echo "   Status: $status"
    if [[ "$status" == "200" ]]; then
        echo "✅ Household config accessible"
    elif [[ "$status" == "404" ]]; then
        echo "⚠️  Household config not found (may need WireGuard setup)"
    else
        echo "⚠️  Household config returned $status"
    fi
else
    echo "❌ Cannot test household.conf access"
fi

# Test external access simulation
echo ""
echo "Testing external access (via test-client container)..."
if docker exec test-client curl -s -I http://pi-simulator/ 2>/dev/null | head -1; then
    echo "✅ External access test container works"
else
    echo "⚠️  External access test needs container networking check"
fi

echo ""
echo "📋 SIMULATION STATUS SUMMARY:"
echo "   - Pi container: Running"
echo "   - Docker-in-Docker: Available" 
echo "   - SSH access: ssh pi@localhost -p 2222"
echo "   - HTTP access: http://localhost:8080"
echo "   - Frigate: http://localhost:5000"
echo ""
echo "Next steps:"
echo "   1. Run 'make sim-deploy' to deploy crooked-sentry"
echo "   2. Run 'make sim-test' to test all requirements"
echo "   3. Use 'make sim-shell' to access the Pi simulation"