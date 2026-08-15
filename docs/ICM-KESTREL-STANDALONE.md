# ICM: Kestrel v2.0 Standalone Repository

## Purpose
Kestrel v2.0 is a standalone inference accelerator and policy layer, built with Zig + LuaJIT FFI.

## Launch Commands

### Start Ollama (LLM backend)
```bash
OLLAMA_MODELS=/mnt/d/Ollama/models ollama serve
Start Kestrel Server
bash
cd /mnt/d/moabi/gullwing-kestrel
python3 kestrel_server_final.py
Start Gullwing (separate repo)
bash
cd /mnt/d/gullwing-clean
luajit src/moabi-serve.lua
cd src/extension && python3 -m http.server 8081
Services
Service	Port	URL
Kestrel API	9394	http://127.0.0.1:9394/health
Kestrel Frontend	9394	http://127.0.0.1:9394/
Gullwing API	9393	http://127.0.0.1:9393/health
Gullwing Frontend	8081	http://127.0.0.1:8081/unified.html
Ollama	11434	http://127.0.0.1:11434
Models
Phi4-mini (2.5GB) — LLM interpretation

Llama 3.2 1B (1.3GB) — quick triage

OLMoE 7B (4GB) — colibri test target

Qwen 3.8 27B (14GB) — future default

Directory Structure
text
/mnt/d/moabi/gullwing-kestrel/   ← Kestrel v2.0 (this repo)
/mnt/d/gullwing-clean/           ← Gullwing (separate repo)
/mnt/d/Ollama/models/            ← Model weights
/mnt/d/colibri-models/           ← Colibri test models
