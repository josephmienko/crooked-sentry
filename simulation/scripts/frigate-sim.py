#!/usr/bin/env python3
"""
Frigate Simulation Server
Generates mock camera feeds using PIL instead of requiring real cameras.
"""
import json
import io
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from PIL import Image, ImageDraw, ImageFont
import datetime


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
        
        # Draw text with shadow effect for better visibility
        draw.text((x + 2, y + 2), text, fill=(0, 0, 0), font=font_large)  # Shadow
        draw.text((x, y), text, fill=(0, 120, 215), font=font_large)  # Main text
        
        # Add timestamp (updates each request to simulate live feed)
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
        pass  # Suppress HTTP request logs


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 5000), FrigateHandler)
    print("🎥 Frigate simulation with mock camera feeds running on port 5000")
    print("   API endpoints:")
    print("   - GET /api/version")
    print("   - GET /api/config")
    print("   - GET /api/events")
    print("   - GET /api/stats")
    print("   - GET /api/front_door/latest.jpg")
    print("   - GET /api/backyard/latest.jpg")
    server.serve_forever()
