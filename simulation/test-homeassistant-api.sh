#!/usr/bin/env bash
# Test Home Assistant API endpoints
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8123}"

echo "🏠 Testing Home Assistant API at $BASE_URL"
echo ""

echo "1️⃣ Testing root API endpoint..."
curl -sS "$BASE_URL/api/" | jq -r '.message'
echo ""

echo "2️⃣ Testing config endpoint..."
curl -sS "$BASE_URL/api/config" | jq '{version, components: .components[:3]}'
echo ""

echo "3️⃣ Listing all states..."
curl -sS "$BASE_URL/api/states" | jq 'length'
echo " entities found"
echo ""

echo "4️⃣ Getting Roku state..."
curl -sS "$BASE_URL/api/states/media_player.roku" | jq '{entity_id, state, source: .attributes.source, volume: .attributes.volume_level}'
echo ""

echo "4b️⃣ Getting Sensi climate state..."
curl -sS "$BASE_URL/api/states/climate.sensi" | jq '{entity_id, state, current: .attributes.current_temperature, target: .attributes.target_temperature, low: .attributes.target_temp_low, high: .attributes.target_temp_high, hvac_action: .attributes.hvac_action}'
echo ""

echo "5️⃣ Listing media_player services..."
curl -sS "$BASE_URL/api/services" | jq '.[] | select(.domain == "media_player") | .services | keys' | head -5
echo ""

echo "6️⃣ Testing service call: select_source -> Netflix..."
curl -sS -X POST "$BASE_URL/api/services/media_player/select_source" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "media_player.roku", "source": "Netflix"}' | jq '.[0].context.id'
echo ""

echo "7️⃣ Verifying state changed to Netflix..."
curl -sS "$BASE_URL/api/states/media_player.roku" | jq '{state, source: .attributes.source}'
echo ""

echo "8️⃣ Testing media_play service..."
curl -sS -X POST "$BASE_URL/api/services/media_player/media_play" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "media_player.roku"}' | jq '.[0].context.id'
echo ""

echo "9️⃣ Testing volume_set service..."
curl -sS -X POST "$BASE_URL/api/services/media_player/volume_set" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "media_player.roku", "volume_level": 0.8}' | jq '.[0].context.id'
echo ""

echo "🔟 Final Roku state..."
curl -sS "$BASE_URL/api/states/media_player.roku" | jq '{entity_id, state, source: .attributes.source, volume: .attributes.volume_level, muted: .attributes.is_volume_muted}'
echo ""

echo "1️⃣1️⃣ Setting climate to heat_cool 20-24..."
curl -sS -X POST "$BASE_URL/api/services/climate/set_hvac_mode" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "climate.sensi", "hvac_mode": "heat_cool"}' | jq '.[0].context.id'
curl -sS -X POST "$BASE_URL/api/services/climate/set_temperature" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "climate.sensi", "target_temp_low": 20, "target_temp_high": 24}' | jq '.[0].context.id'
curl -sS "$BASE_URL/api/states/climate.sensi" | jq '{mode: .state, low: .attributes.target_temp_low, high: .attributes.target_temp_high, action: .attributes.hvac_action}'
echo ""

echo "1️⃣2️⃣ Setting climate to heat 21C and fan on, eco preset..."
curl -sS -X POST "$BASE_URL/api/services/climate/set_hvac_mode" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "climate.sensi", "hvac_mode": "heat"}' | jq '.[0].context.id'
curl -sS -X POST "$BASE_URL/api/services/climate/set_temperature" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "climate.sensi", "target_temperature": 21}' | jq '.[0].context.id'
curl -sS -X POST "$BASE_URL/api/services/climate/set_fan_mode" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "climate.sensi", "fan_mode": "on"}' | jq '.[0].context.id'
curl -sS -X POST "$BASE_URL/api/services/climate/set_preset_mode" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "climate.sensi", "preset_mode": "eco"}' | jq '.[0].context.id'
curl -sS "$BASE_URL/api/states/climate.sensi" | jq '{mode: .state, target: .attributes.target_temperature, fan: .attributes.fan_mode, preset: .attributes.preset_mode, action: .attributes.hvac_action}'
echo ""

echo "1️⃣3️⃣ Turning climate off..."
curl -sS -X POST "$BASE_URL/api/services/climate/turn_off" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "climate.sensi"}' | jq '.[0].context.id'
curl -sS "$BASE_URL/api/states/climate.sensi" | jq '{mode: .state, action: .attributes.hvac_action}'
echo ""

echo "✅ All Home Assistant API tests passed!"
