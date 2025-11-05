#!/usr/bin/env python3
"""
Frigate Simulation Server
Generates mock camera feeds using PIL instead of requiring real cameras.
"""
import json
import io
import time
import os
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
import datetime
from PIL import Image, ImageDraw, ImageFont


class FrigateHandler(BaseHTTPRequestHandler):
    """
    Handle HTTP GET requests for a simple Frigate simulation API.
    This method dispatches based on the request path \
        (parsed via urlparse(self.path).path)
    and sends JSON responses or image data by calling \
        helper methods on the handler.
    Supported endpoints and behavior:
    - GET /api/version
        - Returns a JSON object describing the simulated service version:
            {"version": str, "latest_version": str, "update_available": bool}
    - GET /api/config
        - Returns the simulation configuration as JSON.
        - Reads configuration from self.server.sim_config if present.
        - If not present, returns a minimal default config:
            {"cameras": {}, "mqtt": {"enabled": False}}.
    - GET /api/events/{event_id}/thumbnail.jpg
        - Calls self.send_event_thumbnail(event_id) to stream \
            or send the thumbnail image
            for the specified event id. The event_id is \
            extracted from the path.
    - GET /api/events
        - Builds and returns a JSON list of event objects derived from
            self.server.events_template (expected to be an iterable of \
            dict-like templates).
        - For each template event:
            - start_offset_sec (optional) is interpreted as seconds \
                in the past; start_time =
                now - start_offset_sec. Defaults to 0 if missing.
            - duration_sec (optional) is added to start_time to \
                produce end_time. Defaults to 0.
            - The returned event object includes computed numeric \
                start_time and end_time
                (UNIX epoch seconds), a thumbnail URL \
                at /api/events/{id}/thumbnail.jpg, and
                excludes the template-only fields start_offset_sec \
                and duration_sec.
        - Uses time.time() as the reference "now".
    - GET /api/stats
        - Returns a JSON object with example statistics:
            {"cpu_usages": {...}, "detectors": {...}, "service": \
            {"uptime": ..., "version": ...}}
    - GET /api/{camera}/latest.jpg
        - Calls self.send_camera_snapshot(camera_name) \
            where camera_name is extracted
            from the path to return the latest camera snapshot image.
    Fallback behavior:
    - Any other path returns a 404 JSON response \
        {"error": "Not found"} with
        Content-Type: application/json. The method uses \
        send_response, send_header,
        end_headers and writes JSON bytes to self.wfile for raw responses.
    Notes and side effects:
    - This method relies on helper methods provided by the \
        request handler class:
        - self.send_json(obj): convenience for sending JSON responses.
        - self.send_event_thumbnail(event_id): send thumbnail \
        image bytes for an event.
        - self.send_camera_snapshot(camera_name): send latest \
        camera image bytes.
    - It also expects optional attributes on self.server:
        - sim_config: dictionary to use for /api/config.
        - events_template: list of event template dictionaries \
        used to synthesize /api/events.
    - Time-dependent behavior: /api/events computes \
        start_time and end_time using the
        current time at request handling, so responses vary over time.
    """
    def do_GET(self):
        if self.path == "/api/version":
            self.send_json({
                "version": "0.13.2-simulation",
                "latest_version": "0.13.2",
                "update_available": False
            })      
        elif self.path == "/api/config":
            # Serve config from external file; fallback to minimal default
            config = getattr(self.server, "sim_config", None)
            if not config:
                config = {"cameras": {}, "mqtt": {"enabled": False}}
            self.send_json(config)
        
        elif self.path.startswith("/api/events/") \
                and self.path.endswith("/thumbnail.jpg"):
            # Extract event ID from /api/events/{event_id}/thumbnail.jpg
            event_id = self.path.split("/")[3]
            self.send_event_thumbnail(event_id)

        elif self.path.startswith("/api/events"):
            template = getattr(self.server, "events_template", [])
            now = time.time()
            events = []
            for ev in template:
                start_offset = float(ev.get("start_offset_sec", 0))
                duration = float(ev.get("duration_sec", 0))
                start_time = now - start_offset
                end_time = start_time + duration
                item = {**ev}
                item["start_time"] = start_time
                item["end_time"] = end_time
                item["thumbnail"] = f"/api/events/{ev.get('id')}/thumbnail.jpg"
                # remove template-only fields
                item.pop("start_offset_sec", None)
                item.pop("duration_sec", None)
                events.append(item)
            self.send_json(events)
        
        elif self.path == "/api/stats":
            self.send_json({
                "cpu_usages": {"frigate": 5.2},
                "detectors": {"cpu": {"inference_speed": 50.0}},
                "service": {"uptime": 3600, "version": "0.13.2-simulation"}
            })

        elif self.path.startswith("/api/") and self.path.endswith(
                "/latest.jpg"):
            # Extract camera name from /api/{camera}/latest.jpg
            camera_name = self.path.split("/")[2]
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
            font_large = \
                ImageFont.truetype(
                    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 60
                    )
            font_small = \
                ImageFont.truetype(
                    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 24
                )
        except (OSError, IOError):
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
        draw.text((x + 2, y + 2), text, fill=(0, 0, 0), font=font_large)
        draw.text((x, y), text, fill=(0, 120, 215), font=font_large)
        
        # Add timestamp (updates each request to simulate live feed)
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        draw.text((20, 20), f"SIMULATION - {timestamp}", fill=(180, 180, 180),
                  font=font_small)
        
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
    
    def send_event_thumbnail(self, event_id):
        """Generate a mock event thumbnail with event details"""
        # Create a smaller thumbnail image
        img = Image.new("RGB", (320, 180), color=(40, 40, 50))
        draw = ImageDraw.Draw(img)
        
        # Try to load fonts
        try:
            font_large = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
            font_small = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
        except (OSError, IOError):
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        # Look up label and camera from preloaded template mapping
        mapping = getattr(self.server, "event_id_map", {})
        info = mapping.get(event_id, {"label": "unknown", "camera": "Unknown"})
        label = info.get("label", "unknown")
        camera = "Front Door" if info.get("camera") == "front_door" \
            else ("Backyard" if info.get("camera") == "backyard" 
                  else info.get("camera", "Unknown"))

        # Draw detection label
        text = label.upper()
        bbox = draw.textbbox((0, 0), text, font=font_large)
        text_width = bbox[2] - bbox[0]
        x = (320 - text_width) // 2
        y = 70
        
        # Draw with shadow
        draw.text((x + 1, y + 1), text, fill=(0, 0, 0), font=font_large)
        draw.text((x, y), text, fill=(255, 200, 0), font=font_large)
        
        # Add event ID at top
        draw.text((10, 10), f"Event: {event_id}", fill=(150, 150, 150),
                  font=font_small)
        
        # Add camera location at bottom
        draw.text((10, 160), camera, fill=(150, 150, 150), font=font_small)
        
        # Add detection indicator
        draw.ellipse([280, 10, 300, 30], fill=(255, 0, 0))
        draw.text((285, 13), "●", fill=(255, 255, 255), font=font_small)
        
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
    parser = argparse.ArgumentParser(
        description="Run the Frigate simulation server")
    parser.add_argument("--host", default=os.environ.get("HOST", "0.0.0.0"),
                        help="Host interface to bind")
    parser.add_argument("--port", type=int, default=int(os.environ.get(
        "PORT", "5000")),
                        help="Port to listen on")
    parser.add_argument("--events-file", default=os.environ.get(
        "EVENTS_FILE", None),
                        help="Path to events template JSON")
    parser.add_argument("--config-file", default=os.environ.get(
        "CONFIG_FILE", None),
                        help="Path to config JSON")
    args = parser.parse_args()

    # Resolve default data file paths with sensible fallbacks
    # Priority:
    # 1) Explicit --events-file / --config-file args
    # 2) DATA_DIR env var (if provided)
    # 3) /opt/crooked-services/data (inside simulator container)
    # 4) <repo>/simulation/data relative to this script (when run from repo)
    data_dir_candidates = []
    if os.environ.get("DATA_DIR"):
        data_dir_candidates.append(os.environ["DATA_DIR"])  # explicit override
    data_dir_candidates.append("/opt/crooked-services/data")  # in-container path
    # repo-relative (works when run directly from repo checkout)
    script_root = os.path.dirname(os.path.abspath(__file__))
    repo_guess = os.path.abspath(os.path.join(script_root, os.pardir, os.pardir, "simulation", "data"))
    data_dir_candidates.append(repo_guess)

    def first_existing(path_list):
        for p in path_list:
            if p and os.path.isdir(p):
                return p
        return None

    resolved_data_dir = first_existing(data_dir_candidates)
    default_events = os.path.join(resolved_data_dir, "events.template.json") if resolved_data_dir else None
    default_config = os.path.join(resolved_data_dir, "config.json") if resolved_data_dir else None

    events_path = args.events_file or default_events
    config_path = args.config_file or default_config

    # Preload config and events template
    sim_config = None
    events_template = []
    event_id_map = {}
    try:
        if config_path and os.path.exists(config_path):
            with open(config_path, "r") as f:
                sim_config = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Warning: failed to load config.json: {e}")
        sim_config = None
    try:
        if events_path and os.path.exists(events_path):
            with open(events_path, "r") as f:
                events_template = json.load(f)
            for ev in events_template:
                event_id_map[ev.get("id")] = {"label": ev.get("label"), 
                                              "camera": ev.get("camera")}
    except (OSError, json.JSONDecodeError) as e:
        print(f"Warning: failed to load events.template.json: {e}")
        events_template = []

    server = HTTPServer((args.host, args.port), FrigateHandler)
    # Attach preloaded data to server for handler access
    server.sim_config = sim_config
    server.events_template = events_template
    server.event_id_map = event_id_map
    print(f"🎥 Frigate simulation with mock camera feeds running on\
          {args.host}:{args.port}")
    print("   API endpoints:")
    print("   - GET /api/version")
    print("   - GET /api/config")
    print("   - GET /api/events (20 mock events)")
    print("   - GET /api/stats")
    print("   - GET /api/front_door/latest.jpg")
    print("   - GET /api/backyard/latest.jpg")
    print("   - GET /api/events/{event_id}/thumbnail.jpg")
    server.serve_forever()
