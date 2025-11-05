#!/bin/bash
# Simulation setup script

echo "=== CROOKED-SERVICES SIMULATION SETUP ==="

# 1. Create household.conf (WireGuard config for simulation)
echo "Creating household.conf..."
docker exec crooked-sentry-pi-sim bash -c 'cat > /var/www/info/household.conf << EOF
[Interface]
PrivateKey = SIMULATION_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 10.0.0.1

[Peer]
PublicKey = SIMULATION_PUBLIC_KEY  
Endpoint = localhost:51821
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF'

# 2. Start Frigate simulation with PIL-generated mock camera feeds
echo "Starting Frigate simulation with mock camera feeds..."
docker exec crooked-sentry-pi-sim bash -c 'cat > /tmp/frigate-sim.py << '\''EOF'\''
#!/usr/bin/env python3
import json
import io
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from PIL import Image, ImageDraw, ImageFont

class FrigateHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        
        if path == "/api/version":
            self.send_json({
                "version": "0.13.2-simulation",
                "latest_version": "0.13.2",
                "update_available": False
            })
        
        elif path == "/api/config":
            self.send_json({
                "cameras": {
                    "front_door": {
                        "name": "front_door",
                        "enabled": True,
                        "ffmpeg": {"inputs": [{"path": "rtsp://simulation/front_door"}]},
                        "detect": {"enabled": True, "width": 1280, "height": 720},
                        "record": {"enabled": True},
                        "snapshots": {"enabled": True}
                    },
                    "backyard": {
                        "name": "backyard",
                        "enabled": True,
                        "ffmpeg": {"inputs": [{"path": "rtsp://simulation/backyard"}]},
                        "detect": {"enabled": True, "width": 1920, "height": 1080},
                        "record": {"enabled": True},
                        "snapshots": {"enabled": True}
                    }
                },
                "mqtt": {"enabled": False},
                "detectors": {"cpu": {"type": "cpu"}},
                "model": {"width": 320, "height": 320}
            })
        
        elif path.startswith("/api/events"):
            self.send_json([
                {
                    "id": "sim-event-1",
                    "camera": "front_door",
                    "label": "person",
                    "score": 0.89,
                    "start_time": time.time() - 300,
                    "end_time": time.time() - 240,
                    "has_snapshot": True,
                    "has_clip": True
                },
                {
                    "id": "sim-event-2",
                    "camera": "backyard",
                    "label": "car",
                    "score": 0.76,
                    "start_time": time.time() - 600,
                    "end_time": time.time() - 540,
                    "has_snapshot": True,
                    "has_clip": True
                }
            ])
        
        elif path == "/api/stats":
            self.send_json({
                "cpu_usages": {"frigate": 5.2},
                "detectors": {"cpu": {"inference_speed": 50.0}},
                "service": {"uptime": 3600, "version": "0.13.2-simulation"}
            })
        
        elif path.startswith("/api/") and path.endswith("/latest.jpg"):
            # Extract camera name from /api/{camera}/latest.jpg
            camera_name = path.split("/")[2]
            self.send_camera_snapshot(camera_name)
        
        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Not found"}).encode())
    
    def send_json(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def send_camera_snapshot(self, camera_name):
        """Generate a mock camera snapshot with PIL"""
        # Generate a placeholder image with camera name
        img = Image.new("RGB", (1280, 720), color=(30, 30, 40))
        draw = ImageDraw.Draw(img)
        
        # Try to load a nice font, fall back to default if not available
        try:
            font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 60)
            font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 24)
        except:
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        # Draw camera name (centered)
        text = camera_name.replace("_", " ").title()
        bbox = draw.textbbox((0, 0), text, font=font_large)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        x = (1280 - text_width) // 2
        y = (720 - text_height) // 2
        
        # Draw text with shadow effect
        draw.text((x + 2, y + 2), text, fill=(0, 0, 0), font=font_large)
        draw.text((x, y), text, fill=(0, 120, 215), font=font_large)
        
        # Add timestamp
        import datetime
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        draw.text((20, 20), f"SIMULATION - {timestamp}", fill=(180, 180, 180), font=font_small)
        
        # Add "LIVE" indicator
        draw.text((20, 680), "● LIVE", fill=(255, 0, 0), font=font_small)
        
        # Convert to JPEG
        buffer = io.BytesIO()
        img.save(buffer, format="JPEG", quality=85)
        buffer.seek(0)
        
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.send_header("Content-Length", str(len(buffer.getvalue())))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(buffer.getvalue())
    
    def log_message(self, format, *args):
        pass  # Suppress logs

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 5000), FrigateHandler)
    print("Frigate simulation with mock camera feeds running on port 5000")
    server.serve_forever()
EOF'

# Make it executable and run in background
docker exec crooked-sentry-pi-sim chmod +x /tmp/frigate-sim.py
docker exec -d crooked-sentry-pi-sim python3 /tmp/frigate-sim.py

echo "Waiting for services to start..."
sleep 5

# 3. Test all requirements
echo ""
echo "=== TESTING ALL REQUIREMENTS ==="

echo "🎥 Requirement 1: Camera functionality (Frigate)"
if docker exec crooked-sentry-pi-sim curl -s http://localhost:5000/api/version | grep -q version; then
    echo "   ✅ Frigate API responding"
else
    echo "   ❌ Frigate API not responding"
fi

echo ""
echo "🏠 Requirement 2: LAN/VPN user access (trusted)"
if curl -s http://localhost:8080/ | grep -q "Crooked"; then
    echo "   ✅ Main site accessible"
else
    echo "   ⚠️  Main site accessible but content differs"
fi

if curl -s http://localhost:8080/household.conf | grep -q "Interface"; then
    echo "   ✅ Household config accessible"
else
    echo "   ❌ Household config not accessible"
fi

echo ""
echo "🌐 Requirement 3: External user access (untrusted)"
if docker exec test-client curl -s http://pi-simulator/ | grep -q "html"; then
    echo "   ✅ External access works (should show default page)"
else
    echo "   ❌ External access failed"
fi

echo ""
echo "🔍 DETAILED SERVICE STATUS:"
echo "   SSH: ssh pi@localhost -p 2222 (password: raspberry)"
echo "   Web: http://localhost:8080"
echo "   Frigate: http://localhost:15000" 
echo "   WireGuard Config: http://localhost:8080/household.conf"

echo ""
echo "✅ Simulation setup complete!"