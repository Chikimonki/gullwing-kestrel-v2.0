#!/usr/bin/env python3
"""Kestrel v2.0 with REAL Solver + LLM + Deep Analysis"""
import http.server
import json
import subprocess
import urllib.parse
import os

class KestrelHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)
        
        # Serve frontend
        if path == '/' or path == '/index.html':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            with open('/mnt/d/moabi/gullwing-kestrel/kestrel_frontend_final.html', 'r') as f:
                self.wfile.write(f.read().encode())
            return
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        if path == '/health':
            response = self.health()
        elif path == '/analyze':
            binary_path = query.get('path', [''])[0]
            deep = query.get('deep', ['false'])[0] == 'true'
            response = self.analyze(binary_path, deep)
        elif path == '/solver':
            binary_path = query.get('path', [''])[0]
            response = self.run_solver(binary_path)
        elif path == '/llm':
            binary_path = query.get('path', [''])[0]
            response = self.run_llm(binary_path)
        elif path == '/experts':
            response = self.experts()
        else:
            response = {'error': 'Not found'}
        
        self.wfile.write(json.dumps(response).encode())
    
    def run_lua(self, script):
        try:
            result = subprocess.run(
                ['luajit', '-e', script],
                capture_output=True,
                text=True,
                timeout=60,
                cwd='/mnt/d/moabi/gullwing-kestrel'
            )
            return result.stdout.strip() if result.returncode == 0 else None
        except Exception as e:
            return None
    
    def health(self):
        return {
            'status': 'healthy',
            'engine': 'kestrel-v2.0',
            'experts': 8,
            'memory_mb': 0.83,
            'solver': self.check_solver(),
            'llm': self.check_llm(),
        }
    
    def check_solver(self):
        result = subprocess.run(['which', 'wsolve'], capture_output=True, text=True)
        return result.returncode == 0
    
    def check_llm(self):
        result = subprocess.run(
            ['curl', '-s', '-m', '2', 'http://127.0.0.1:11434/api/tags'],
            capture_output=True, text=True
        )
        return 'phi' in result.stdout.lower() if result.stdout else False
    
    def analyze(self, binary_path, deep=False):
        script = f"""
package.path = '/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;' .. package.path
local router = require('integrated_router')
router.init(16 * 1024 * 1024 * 1024)
local analysis = router.analyze_binary('{binary_path}')
if analysis then
    print(string.format('%d|%.3f|%s', analysis.size, analysis.convergence.risk_score, analysis.convergence.verdict))
else
    print('ERROR')
end
"""
        output = self.run_lua(script)
        
        if output and output != 'ERROR':
            parts = output.split('|')
            if len(parts) == 3:
                size, risk, verdict = parts
                return {
                    'success': True,
                    'path': binary_path,
                    'size': int(size),
                    'risk_score': float(risk),
                    'verdict': verdict,
                    'deep_analysis': self.deep_analysis(binary_path) if deep else None,
                }
        
        return {'error': 'Analysis failed'}
    
    def deep_analysis(self, binary_path):
        """Get library dependencies for large binaries"""
        result = subprocess.run(
            ['ldd', binary_path],
            capture_output=True, text=True
        )
        
        libraries = []
        for line in result.stdout.split('\n'):
            if '=>' in line:
                lib = line.split('=>')[0].strip()
                libraries.append(lib)
        
        return {
            'library_count': len(libraries),
            'libraries': libraries[:10],  # First 10
        }
    
    def run_solver(self, binary_path):
        """Actually run Witchcraft Solver if available"""
        if not self.check_solver():
            return {
                'success': False,
                'error': 'Witchcraft Solver not installed',
                'install': 'git clone https://github.com/endrazine/wsolver',
            }
        
        result = subprocess.run(
            ['wsolve', binary_path],
            capture_output=True, text=True,
            timeout=300  # 5 min timeout
        )
        
        return {
            'success': True,
            'output': result.stdout[:500],  # First 500 chars
        }
    
    def run_llm(self, binary_path):
        """Actually call Phi-4-mini via Ollama"""
        if not self.check_llm():
            return {
                'success': False,
                'error': 'Ollama/Phi-4-mini not running',
            }
        
        # First analyze with Kestrel
        analysis = self.analyze(binary_path)
        
        if not analysis.get('success'):
            return {'error': 'Kestrel analysis failed'}
        
        # Build prompt
        prompt = f"Analyze this binary: {binary_path}, size: {analysis['size']} bytes, risk: {analysis['risk_score']}"
        
        # Call Ollama
        result = subprocess.run(
            ['curl', '-s', '-X', 'POST', 'http://127.0.0.1:11434/api/generate',
             '-d', json.dumps({'model': 'phi4-mini', 'prompt': prompt, 'stream': False})],
            capture_output=True, text=True,
            timeout=30
        )
        
        try:
            response = json.loads(result.stdout)
            return {
                'success': True,
                'interpretation': response.get('response', 'No response'),
            }
        except:
            return {'error': 'LLM call failed'}
    
    def experts(self):
        return {
            'success': True,
            'experts': [
                {'id': 1, 'name': 'IDENTITY', 'input_dim': 512, 'output_dim': 128, 'hot': True},
                {'id': 2, 'name': 'STRUCTURE', 'input_dim': 512, 'output_dim': 128, 'hot': True},
                {'id': 3, 'name': 'SEMANTICS', 'input_dim': 256, 'output_dim': 64, 'hot': True},
                {'id': 4, 'name': 'ENTROPY', 'input_dim': 256, 'output_dim': 64, 'hot': True},
                {'id': 5, 'name': 'ML', 'input_dim': 128, 'output_dim': 32, 'hot': False},
                {'id': 6, 'name': 'RUNTIME', 'input_dim': 256, 'output_dim': 64, 'hot': False},
                {'id': 7, 'name': 'MEMORY', 'input_dim': 256, 'output_dim': 64, 'hot': False},
                {'id': 8, 'name': 'MEMORY_DIFF', 'input_dim': 256, 'output_dim': 64, 'hot': False},
            ]
        }
    
    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {format % args}")

if __name__ == '__main__':
    port = 9394
    print(f"Kestrel v2.0 + Solver + LLM")
    print(f"http://127.0.0.1:{port}/")
    server = http.server.HTTPServer(('127.0.0.1', port), KestrelHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
