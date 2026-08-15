#!/bin/bash

echo "=== Starting Kestrel v2.0 Frontend ==="

# Start Kestrel API server in background
echo "Starting Kestrel API server..."
luajit kestrel_server.lua &
KESTREL_PID=$!

# Wait for server to start
sleep 2

# Check if server is running
if curl -s http://127.0.0.1:9394/health > /dev/null; then
    echo "✓ Kestrel API running on http://127.0.0.1:9394"
    echo ""
    echo "Opening frontend..."
    echo "Visit: file:///mnt/d/moabi/gullwing-kestrel/kestrel_frontend.html"
    echo ""
    echo "Or serve with Python:"
    echo "  cd /mnt/d/moabi/gullwing-kestrel"
    echo "  python3 -m http.server 8082"
    echo ""
    echo "Then visit: http://127.0.0.1:8082/kestrel_frontend.html"
else
    echo "✗ Failed to start Kestrel API"
    kill $KESTREL_PID
    exit 1
fi

echo ""
echo "Press Ctrl+C to stop the server"
wait $KESTREL_PID
