# Kestrel Measurement Harness — Contribution to Colibri

## What This Is
A benchmark suite and honest measurement discipline developed during the Kestrel v2.0 campaign.

## What It Measures
- Cold read speeds (real page faults, not mmap illusions)
- Warm read speeds (RAM cache)
- SIMD vs scalar matrix-vector multiplication
- Hybrid storage tiering (NVMe pin / HDD stream)
- Recognition cache hit rates

## Standing Rules
1. Every speed computed from actual bytes touched
2. Assert printed_speed == bytes_touched / elapsed within 1%
3. Drop caches before cold measurements
4. Use fresh files >1GB to defeat host cache
5. Median of 5 runs
6. Print checksums so compiler can't skip work

## Key Findings
- WSL2 bridge caps /mnt/c and /mnt/d at ~195 MB/s
- VM ext4 (~/) achieves 565-1103 MB/s (the real hot tier)
- SIMD matvec: 2.48x (memory-bound, as expected)
- Recognition cache: 51.6x for known binaries
- mmap loading defers reads to first touch (not "245,000x faster")

## Files
- `benchmark_storage.zig` — Honest storage speed measurement
- `benchmark_simd.lua` — SIMD vs scalar comparison
- `benchmark_cache.lua` — Recognition cache hit rate
