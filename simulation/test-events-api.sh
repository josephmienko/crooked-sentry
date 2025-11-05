#!/bin/bash
# Test script for Frigate Events API

echo "🧪 Testing Frigate Events API"
echo "================================"
echo ""

echo "1. Testing /api/events endpoint..."
curl -s http://localhost:8080/api/events | jq '. | length' | xargs -I {} echo "   ✅ Returned {} events"
echo ""

echo "2. Showing first 3 events..."
curl -s http://localhost:8080/api/events | jq '.[0:3] | .[] | {id, label, camera, start_time}'
echo ""

echo "3. Testing event thumbnails..."
mkdir -p /tmp/event-thumbnails
curl -s http://localhost:8080/api/events/evt_001/thumbnail.jpg -o /tmp/event-thumbnails/evt_001.jpg
curl -s http://localhost:8080/api/events/evt_002/thumbnail.jpg -o /tmp/event-thumbnails/evt_002.jpg
curl -s http://localhost:8080/api/events/evt_010/thumbnail.jpg -o /tmp/event-thumbnails/evt_010.jpg
ls -lh /tmp/event-thumbnails/
echo ""

echo "4. Event breakdown by label..."
curl -s http://localhost:8080/api/events | jq '[.[] | .label] | group_by(.) | map({label: .[0], count: length})'
echo ""

echo "5. Event breakdown by camera..."
curl -s http://localhost:8080/api/events | jq '[.[] | .camera] | group_by(.) | map({camera: .[0], count: length})'
echo ""

echo "6. Events from today (last 24 hours)..."
NOW=$(date +%s)
YESTERDAY=$((NOW - 86400))
curl -s http://localhost:8080/api/events | jq --arg yesterday "$YESTERDAY" '[.[] | select(.start_time > ($yesterday | tonumber))] | length' | xargs -I {} echo "   Found {} events from last 24 hours"
echo ""

echo "7. Opening thumbnails..."
open /tmp/event-thumbnails/
echo ""

echo "✅ Testing complete!"
echo ""
echo "API Endpoints tested:"
echo "  - GET /api/events"
echo "  - GET /api/events/{event_id}/thumbnail.jpg"
