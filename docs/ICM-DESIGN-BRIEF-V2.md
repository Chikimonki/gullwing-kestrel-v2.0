# Kestrel v2.0 Revised Design Brief

## Executive Summary
Kestrel v2.0 is an **accelerator and policy layer** for streaming MoE inference, built on colibri's foundation. We do not replace colibri; we contribute back what's general: cross-arch kernels, hybrid storage, live policy, and attestation.

## Honest Position (Post-Review)
- Colibri already has AVX2, async prefetch, expert cache, LRU eviction
- We do **not** claim 1,680x speedup
- Real wins: development velocity, hybrid storage, auditability
- Every claim lands with a measurement

## Architecture


## Target Hardware
- 16GB RAM (below colibri's 25GB floor for GLM-5.2)
- C: 7.5GB free NVMe (fast)
- D: 122GB free HDD (5,400 RPM, slow)
- No GPU required (CPU-only)

## Development Phases
1. Benchmark harness (measure colibri baseline)
2. Hybrid storage (pin hot, stream cold)
3. LuaJIT policy layer (live routing policy)
4. Zig cross-arch kernels (maintainability)
5. Attested engine (compliance)

## Framing
Public: "Builds on colibri's foundation, contributes back what's general."
Not: "Better than colibri."
