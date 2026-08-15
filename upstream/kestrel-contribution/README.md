# Kestrel v2.0 Contribution to Colibri

## What This Is
A working implementation of the "measurable policies rather than promises" principle, built with Zig + LuaJIT FFI.

## Alignment with Colibri's README

| Colibri's Design | Kestrel v2.0 Implementation | Status |
|------------------|----------------------------|--------|
| route → union → place → overlap → learn | Cache → Hot/Cold tier → SIMD kernels → Policy layer | ✅ Built |
| "Measurable policies rather than promises" | 4 hot-swappable LuaJIT policies | ✅ 0.108μs/route |
| "One hierarchy, not limited by tier" | Hybrid storage (565/162 MB/s measured) | ✅ Measured |
| "JIT for weights" | Recognition cache + LRU + learned pins | ✅ 51.6x hit rate |
| "Never wait for disk twice" | mmap + prefetch + batch-union | ✅ Built |
| "Record hardware, commit, exact command" | Benchmark harness with checksums | ✅ Built |
| "A well-controlled failure is more valuable" | Our honest campaign log | ✅ Documented |

## Key Measurements (Your Hardware Reference)

All measurements on i5-8265U, 16GB RAM, WSL2 Ubuntu 24.04:

| Test | Result | Notes |
|------|--------|-------|
| SIMD fp32 matmul | 2.73x over scalar | Parity 1.2e-4 |
| SIMD int8 quantized | 2.97x over scalar | Parity 9.5e-5 |
| Recognition cache | 51.6x for known binaries | LuaJIT JIT-compiled hash |
| Policy routing | 0.108μs/route (greedy) | Hot-swappable at runtime |
| VM ext4 hot tier | 565 MB/s (1GB file) | The real fast path in WSL2 |
| D: HDD cold tier | 162 MB/s (1GB file) | Bridge-capped, prefetch only |

## Files

### Kernels
- `matmul_zig.zig` — Zig AVX2 fp32 + int8 quantized matmul
- `benchmark_colibri_vs_zig.lua` — With known-answer validation

### Policy Layer
- `policy_layer.lua` — 4 hot-swappable routing policies
- `test_policy.lua` — Benchmark with 10,000 routes per policy

### Storage
- `benchmark_storage.zig` — Honest cold/warm read measurement
- `test_three_way.lua` — VM ext4 vs C: bridge vs D: bridge

### Benchmark Discipline
- `STANDING-RULES.md` — The rules that prevent "petabyte fantasies"
- `CAMPAIGN-LOG.md` — Every mistake made and corrected

## The Novel Contribution

**LuaJIT as a hot-swappable policy layer.** Colibri must recompile to change routing policy. Kestrel changes it at runtime:
```lua
set_policy('balanced')   -- instant
set_policy('cache_aware') -- instant, no recompile
set_policy('diverse')    -- A/B test live
This is the experiment harness JustVugg's README asks for: "Change one variable, repeat the run." We can do it without restarting the engine.

License
MIT — same as colibri.
