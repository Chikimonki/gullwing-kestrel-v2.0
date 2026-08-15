#!/bin/bash

# Simple HTTP server using bash and netcat
PORT=9394
ROOT="/mnt/d/moabi/gullwing-kestrel"

echo "=== Kestrel v2.0 HTTP Server ==="
echo "Serving on http://127.0.0.1:$PORT"
echo ""

# Initialize Kestrel once
luajit -e '
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path
local KestrelServer = require("kestrel_server_simple")
KestrelServer.init()
' > /tmp/kestrel_init.log 2>&1

# Function to handle HTTP requests
handle_request() {
    local request="$1"
    local method=$(echo "$request" | head -1 | cut -d' ' -f1)
    local path_query=$(echo "$request" | head -1 | cut -d' ' -f2)
    local path=$(echo "$path_query" | cut -d'?' -f1)
    local query=$(echo "$path_query" | grep -o '\?.*' | cut -d'?' -f2)
    
    # Parse query parameters
    local binary_path=""
    if [[ "$query" == *"path="* ]]; then
        binary_path=$(echo "$query" | sed 's/.*path=\([^&]*\).*/\1/' | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
    fi
    
    case "$path" in
        /health)
            response=$(luajit -e '
                package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path
                local json = require("json")
                local KestrelServer = require("kestrel_server_simple")
                print(json.encode(KestrelServer.health()))
            ')
            ;;
        /analyze)
            if [ -n "$binary_path" ]; then
                response=$(luajit -e "
                    package.path = '/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;' .. package.path
                    local json = require('json')
                    local KestrelServer = require('kestrel_server_simple')
                    print(json.encode(KestrelServer.analyze('$binary_path')))
                ")
            else
                response='{"error":"Missing path parameter"}'
            fi
            ;;
        /experts)
            response=$(luajit -e '
                package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path
                local json = require("json")
                local KestrelServer = require("kestrel_server_simple")
                print(json.encode(KestrelServer.get_experts()))
            ')
            ;;
        /)
            cat "$ROOT/kestrel_frontend.html"
            ;;
        *)
            response='{"error":"Not found"}'
            ;;
    esac
    
    # Send HTTP response
    if [ "$path" = "/" ]; then
        printf "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"
    else
        printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        echo "$response"
    fi
}

# Main server loop using netcat
while true; do
    nc -l -p $PORT -q 1 | while read -r line; do
        if [[ "$line" == "GET "* ]] || [[ "$line" == "POST "* ]]; then
            handle_request "$line"
            break
        fi
    done
done
