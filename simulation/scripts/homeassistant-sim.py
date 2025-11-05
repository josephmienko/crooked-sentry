#!/usr/bin/env python3
"""
Home Assistant API Simulation Server
Provides a mock Home Assistant API for testing integrations.
"""
import json
import time
import os
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from datetime import datetime


class HomeAssistantHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        path = urlparse(self.path).path
        
        if path == "/api/":
            # API discovery endpoint
            self.send_json({
                "message": "API running.",
                "version": "2024.11.0"
            })
        
        elif path == "/api/config":
            # Home Assistant configuration
            self.send_json({
                "latitude": 37.7749,
                "longitude": -122.4194,
                "elevation": 0,
                "unit_system": {
                    "length": "km",
                    "mass": "g",
                    "temperature": "°C",
                    "volume": "L"
                },
                "location_name": "Simulation",
                "time_zone": "America/Los_Angeles",
                "components": [
                    "media_player",
                    "roku",
                    "frigate",
                    "sensor",
                    "binary_sensor",
                    "automation"
                ],
                "config_dir": "/config",
                "whitelist_external_dirs": [],
                "allowlist_external_dirs": [],
                "version": "2024.11.0",
                "config_source": "storage",
                "safe_mode": False,
                "state": "RUNNING",
                "external_url": None,
                "internal_url": "http://localhost:8123"
            })
        
        elif path == "/api/states":
            # All entity states
            states = getattr(self.server, "ha_states", [])
            self.send_json(states)
        
        elif path.startswith("/api/states/"):
            # Get state for specific entity
            entity_id = path.replace("/api/states/", "")
            states = getattr(self.server, "ha_states", [])
            entity = next(
                (s for s in states if s.get("entity_id") == entity_id),
                None
            )
            if entity:
                self.send_json(entity)
            else:
                self.send_error(404, f"Entity {entity_id} not found")
        
        elif path == "/api/services":
            # Available services
            services_data = getattr(
                self.server, "ha_services", {"domains": []}
            )
            # Transform to Home Assistant API format
            result = []
            for domain_info in services_data.get("domains", []):
                domain = domain_info.get("domain")
                services = {}
                for svc in domain_info.get("services", []):
                    services[svc.get("service")] = {
                        "description": svc.get("description", ""),
                        "fields": svc.get("fields", {})
                    }
                result.append({
                    "domain": domain,
                    "services": services
                })
            self.send_json(result)
        
        elif path == "/api/error_log":
            self.send_json({"message": "No errors in simulation"})
        
        elif path == "/api/events":
            # Available event types
            self.send_json([
                {"event": "state_changed"},
                {"event": "service_called"},
                {"event": "roku_command"}
            ])
        
        else:
            self.send_error(404, "Not found")
    
    def do_POST(self):
        path = urlparse(self.path).path
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else b'{}'
        
        try:
            data = json.loads(body.decode('utf-8')) if body else {}
        except json.JSONDecodeError:
            data = {}
        
        if path.startswith("/api/services/"):
            # Service call: /api/services/<domain>/<service>
            parts = path.replace("/api/services/", "").split("/")
            if len(parts) >= 2:
                domain = parts[0]
                service = parts[1]
                self.handle_service_call(domain, service, data)
            else:
                self.send_error(400, "Invalid service path")
        
        elif path.startswith("/api/states/"):
            # Update entity state
            entity_id = path.replace("/api/states/", "")
            self.handle_state_update(entity_id, data)
        
        else:
            self.send_error(404, "Not found")
    
    def handle_service_call(self, domain, service, data):
        """Handle service calls (media_player.play, etc.)"""
        entity_id = data.get("entity_id", "")
        
        # Log the service call
        print(f"🎬 Service called: {domain}.{service} on {entity_id or 'all'}")
        if data:
            print(f"   Data: {json.dumps(data, indent=2)}")
        
        # Update state based on service call
        if domain == "media_player" and entity_id:
            states = getattr(self.server, "ha_states", [])
            entity = next(
                (s for s in states if s.get("entity_id") == entity_id),
                None
            )
            
            if entity:
                now = datetime.utcnow().isoformat() + "Z"
                
                if service == "turn_on":
                    entity["state"] = "idle"
                elif service == "turn_off":
                    entity["state"] = "off"
                elif service == "media_play":
                    entity["state"] = "playing"
                elif service == "media_pause":
                    entity["state"] = "paused"
                elif service == "media_stop":
                    entity["state"] = "idle"
                elif service == "volume_set":
                    vol = data.get("volume_level", 0.5)
                    entity["attributes"]["volume_level"] = vol
                elif service == "volume_mute":
                    muted = data.get("is_volume_muted", True)
                    entity["attributes"]["is_volume_muted"] = muted
                elif service == "select_source":
                    source = data.get("source", "Home")
                    entity["attributes"]["source"] = source
                    entity["attributes"]["app_name"] = source
                    entity["state"] = "playing" if source != "Home" else "idle"
                
                entity["last_updated"] = now
                entity["last_changed"] = now

        elif domain == "climate" and entity_id:
            states = getattr(self.server, "ha_states", [])
            entity = next(
                (s for s in states if s.get("entity_id") == entity_id),
                None
            )
            if entity:
                now = datetime.utcnow().isoformat() + "Z"
                attrs = entity.setdefault("attributes", {})
                # Defaults for safety
                hvac_mode = attrs.get("hvac_mode", entity.get("state", "off"))

                if service == "turn_on":
                    entity["state"] = attrs.get("hvac_mode", "heat_cool")
                elif service == "turn_off":
                    entity["state"] = "off"
                    attrs["hvac_action"] = "off"
                elif service == "set_hvac_mode":
                    hvac_mode = data.get("hvac_mode", hvac_mode)
                    entity["state"] = hvac_mode
                    attrs["hvac_mode"] = hvac_mode
                    # Normalize target fields depending on mode
                    if hvac_mode == "heat_cool":
                        # keep range
                        pass
                    else:
                        # collapse to single setpoint
                        if attrs.get("target_temperature") is None:
                            # pick midpoint of range if present
                            low = attrs.get("target_temp_low")
                            high = attrs.get("target_temp_high")
                            if low is not None and high is not None:
                                attrs["target_temperature"] = (
                                    (low + high) / 2.0
                                )
                        attrs.pop("target_temp_low", None)
                        attrs.pop("target_temp_high", None)
                elif service == "set_temperature":
                    if "target_temperature" in data:
                        attrs["target_temperature"] = (
                            data["target_temperature"]
                        )
                        attrs.pop("target_temp_low", None)
                        attrs.pop("target_temp_high", None)
                    else:
                        if "target_temp_low" in data:
                            attrs["target_temp_low"] = data["target_temp_low"]
                        if "target_temp_high" in data:
                            attrs["target_temp_high"] = (
                                data["target_temp_high"]
                            )
                        attrs.pop("target_temperature", None)
                elif service == "set_fan_mode":
                    if "fan_mode" in data:
                        attrs["fan_mode"] = data["fan_mode"]
                elif service == "set_preset_mode":
                    attrs["preset_mode"] = data.get("preset_mode")

                # Update action heuristic
                cur = attrs.get("current_temperature")
                tgt = attrs.get("target_temperature")
                low = attrs.get("target_temp_low")
                high = attrs.get("target_temp_high")
                action = "idle"
                mode = entity.get("state")
                if mode == "heat" and cur is not None and tgt is not None:
                    action = "heating" if cur < tgt - 0.2 else "idle"
                elif mode == "cool" and cur is not None and tgt is not None:
                    action = "cooling" if cur > tgt + 0.2 else "idle"
                elif (
                    mode == "heat_cool"
                    and cur is not None
                    and low is not None
                    and high is not None
                ):
                    if cur < low - 0.2:
                        action = "heating"
                    elif cur > high + 0.2:
                        action = "cooling"
                    else:
                        action = "idle"
                attrs["hvac_action"] = action

                entity["last_updated"] = now
                entity["last_changed"] = now
        
        # Return success response
        self.send_json([{
            "context": {
                "id": f"sim{int(time.time())}",
                "parent_id": None,
                "user_id": None
            }
        }])
    
    def handle_state_update(self, entity_id, data):
        """Handle direct state updates via POST to /api/states/<id>"""
        states = getattr(self.server, "ha_states", [])
        entity = next(
            (s for s in states if s.get("entity_id") == entity_id),
            None
        )
        
        now = datetime.utcnow().isoformat() + "Z"
        
        if entity:
            # Update existing entity
            if "state" in data:
                entity["state"] = data["state"]
            if "attributes" in data:
                entity["attributes"].update(data["attributes"])
            entity["last_updated"] = now
            entity["last_changed"] = now
            self.send_json(entity)
        else:
            # Create new entity
            new_entity = {
                "entity_id": entity_id,
                "state": data.get("state", "unknown"),
                "attributes": data.get("attributes", {}),
                "last_changed": now,
                "last_updated": now,
                "context": {
                    "id": f"sim{int(time.time())}",
                    "parent_id": None,
                    "user_id": None
                }
            }
            states.append(new_entity)
            self.send_json(new_entity)
    
    def send_json(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def send_error(self, code, message=None, explain=None):
        # Emit JSON errors instead of HTML
        payload = {"message": message or "Error", "code": code}
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode())
    
    def log_message(self, fmt, *fmt_args):
        pass  # Suppress HTTP request logs


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Run the Home Assistant simulation server")
    parser.add_argument("--host", default=os.environ.get(
        "HOST", "0.0.0.0"), help="Host interface to bind")
    parser.add_argument("--port", type=int, default=int(os.environ.get(
        "PORT", "8123")), help="Port to listen on")
    parser.add_argument("--roku-state", default=os.environ.get(
        "ROKU_STATE", None), help="Path to Roku state JSON")
    parser.add_argument("--services", default=os.environ.get(
        "SERVICES_FILE", None), help="Path to services JSON")
    parser.add_argument("--sensi-state", default=os.environ.get(
        "SENSI_STATE", None), help="Path to Sensi climate state JSON")
    args = parser.parse_args()

    # Resolve default data file paths
    base_dir = os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))  # simulation/
    default_roku = os.path.join(
        base_dir, "data", "homeassistant", "roku_state.json")
    default_services = os.path.join(
        base_dir, "data", "homeassistant", "services.json")
    default_sensi = os.path.join(
        base_dir, "data", "homeassistant", "sensi_state.json")
    roku_path = args.roku_state or default_roku
    services_path = args.services or default_services
    sensi_path = args.sensi_state or default_sensi

    # Load initial states
    ha_states = []
    try:
        if os.path.exists(roku_path):
            with open(roku_path, "r", encoding="utf-8") as f:
                roku_state = json.load(f)
                # Update timestamps to now
                now_ts = datetime.utcnow().isoformat() + "Z"
                roku_state["last_changed"] = now_ts
                roku_state["last_updated"] = now_ts
                ha_states.append(roku_state)
                print(f"✅ Loaded Roku state from {roku_path}")
    except (OSError, json.JSONDecodeError) as e:
        print(f"Warning: failed to load roku_state.json: {e}")

    # Load Sensi climate state
    try:
        if os.path.exists(sensi_path):
            with open(sensi_path, "r", encoding="utf-8") as f:
                sensi_state = json.load(f)
                now_ts = datetime.utcnow().isoformat() + "Z"
                sensi_state["last_changed"] = now_ts
                sensi_state["last_updated"] = now_ts
                ha_states.append(sensi_state)
                print(
                    f"✅ Loaded Sensi climate state from {sensi_path}")
    except (OSError, json.JSONDecodeError) as e:
        print(f"Warning: failed to load sensi_state.json: {e}")

    # Load services
    ha_services = {"domains": []}
    try:
        if os.path.exists(services_path):
            with open(services_path, "r", encoding="utf-8") as f:
                ha_services = json.load(f)
                print(f"✅ Loaded services from {services_path}")
    except (OSError, json.JSONDecodeError) as e:
        print(f"Warning: failed to load services.json: {e}")

    server = HTTPServer((args.host, args.port), HomeAssistantHandler)
    server.ha_states = ha_states
    server.ha_services = ha_services
    
    print(f"🏠 Home Assistant simulation running on {args.host}:{args.port}")
    print("   API endpoints:")
    print("   - GET  /api/")
    print("   - GET  /api/config")
    print("   - GET  /api/states")
    print("   - GET  /api/states/media_player.roku")
    print("   - GET  /api/states/climate.sensi")
    print("   - GET  /api/services")
    print("   - POST /api/services/media_player/turn_on")
    print("   - POST /api/services/media_player/select_source")
    print("   - POST /api/services/climate/set_temperature")
    print("   - POST /api/services/climate/set_hvac_mode")
    print(f"   Loaded {len(ha_states)} entities")
    
    server.serve_forever()
