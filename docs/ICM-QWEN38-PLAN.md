# Qwen 3.8 27B on 16GB — Integration Plan

## Why Qwen 3.8 27B
- Fits 16GB with IQ4_XS quant (~13-14GB used)
- Hybrid attention: 48 linear + 16 full = small KV cache
- MTP (Multi-Token Prediction) supported
- Apache 2.0 license
- 7-10 tok/s on 16GB VRAM (per video review)
- 262K context window usable locally

## How Kestrel v2.0 Helps
- Zig kernels: 2.97x over scalar on int8 quantized
- LuaJIT policy layer: hot-swappable routing
- Recognition cache: 51.6x for known patterns
- Hybrid storage: 565/162 MB/s tiers

## Integration Path
1. Download Qwen 3.8 27B IQ4_XS GGUF (~14GB)
2. Test through Ollama (baseline)
3. Test through colibri (if supported)
4. Test through Kestrel v2.0 (our accelerator)

## Expected Speedup
- Ollama baseline: ~7-10 tok/s (per review)
- Kestrel + Zig kernels: potentially 2-3x faster
- Kestrel + policy layer: better expert routing
- Kestrel + cache: instant for repeated tokens

## License
Apache 2.0 — no restrictions on use.
