#!/usr/bin/env python3
"""Kestrel v2.0 HTTP Server"""
import http.server
import json
import subprocess
import urllib.parse
import os
import sys

# Add Lua path
os.environ['LUA_PATH'] = '/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;;'

class KestrelHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)
        
        # Set headers
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        # Route requests
        if path == '/health':
            response = self.run_lua('health')
        elif path == '/analyze':
            binary_path = query.get('path', [''])[0]
            if binary_path:
                response = self.run_lua('analyze', binary_path)
            else:
                response = {'error': 'Missing path parameter'}
        elif path == '/experts':
            response = self.run_lua('experts')
        elif path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            with open('/mnt/d/moabi/gullwing-kestrel/kestrel_frontend.html', 'r') as f:
                self.wfile.write(f.read().encode())
            return
        else:
            response = {'error': 'Not found', 'path': path}
        
        self.wfile.write(json.dumps(response).encode())
    
    def run_lua(self, command, *args):
        """Run Lua command and parse JSON response"""
        lua_script = f"""
        package.path = '/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;' .. package.path
        local json = require('json')
        local KestrelServer = require('kestrel_server_simple')
        
        if '{command}' == 'health' then
            print(json.encode(KestrelServer.health()))
        elseif '{command}' == 'analyze' then
            print(json.encode(KestrelServer.analyze('{args[0] if args else ""}')))
        elseif '{command}' == 'experts' then
            print(json.encode(KestrelServer.get_experts()))
        end
        """
        
        try:
            result = subprocess.run(
                ['luajit', '-e', lua_script],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                return json.loads(result.stdout)
            else:
                return {'error': result.stderr}
        except Exception as e:
            return {'error': str(e)}
    
    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {format % args}")

if __name__ == '__main__':
    port = 9394
    print(f"=== Kestrel v2.0 HTTP Server ===")
    print(f"Serving on http://127.0.0.1:{port}")
    print(f"Frontend: http://127.0.0.1:{port}/")
    print(f"API: http://127.0.0.1:{port}/health")
    print()
    
    server = http.server.HTTPServer(('127.0.0.1', port), KestrelHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.server_close()
