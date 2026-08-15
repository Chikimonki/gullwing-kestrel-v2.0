#!/bin/bash
echo "=== Kestrel v2.0 Launcher ==="

# Start Ollama if not running
if ! curl -s -m 2 http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
    echo "Starting Ollama..."
    OLLAMA_MODELS=/mnt/d/Ollama/models ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3
else
    echo "Ollama already running"
fi

# Start Kestrel server if not running
if ! curl -s -m 2 http://127.0.0.1:9394/health > /dev/null 2>&1; then
    echo "Starting Kestrel server..."
    cd /mnt/d/moabi/gullwing-kestrel
    python3 kestrel_server_final.py > /tmp/kestrel.log 2>&1 &
    sleep 2
else
    echo "Kestrel server already running"
fi

echo ""
echo "=== Ready ==="
echo "Frontend: http://127.0.0.1:9394/"
echo "Ollama: http://127.0.0.1:11434/"
echo ""
echo "Stop with: pkill ollama; pkill -f kestrel_server"
