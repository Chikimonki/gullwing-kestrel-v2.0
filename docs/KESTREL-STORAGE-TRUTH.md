# Kestrel Storage Truth — Final Measurements

## Date: 2026-08-15 (Campaign complete)

## The Numbers That Matter

| Tier | Location | Speed | Role |
|------|----------|-------|------|
| Hot pin | ~/kestrel/hot (ext4) | 565 MB/s measured | Serve inference, 2GB budget |
| Cold stream | /mnt/d/models | 162 MB/s measured | Background prefetch, 16MB chunks |

## The Journey

1. **Petabyte fantasy** (1,000,000,000 MB/s) — dead code elimination
2. **Correction** — added checksum, compiler can't optimise away
3. **Discipline** — byte counting, cold/warm separation, honest labels
4. **Bedrock** — 1GB fresh file, three-way test, real numbers

## Honest SIMD Win
- Scalar: 4.97ms per iteration
- SIMD: 2.00ms per iteration
- **Speedup: 2.48x** (memory-bound, as expected)

## Lessons Earned

1. If a benchmark shows >100GB/s, the compiler deleted your loop
2. mmap doesn't load — it maps. Cold read is the real load.
3. WSL2 bridge caps /mnt/c and /mnt/d at ~195MB/s
4. The VM's ext4 is the real fast path
5. Count bytes actually touched, not bytes requested
6. Print checksums so the compiler can't skip work

## Standing Rules

- Every speed computed from actual bytes touched
- Assert printed_speed == bytes_touched / elapsed within 1%
- Drop caches before cold measurements
- Use fresh files >1GB to defeat host cache
- Median of 5 runs, watch for thermal throttling

## The Doctrine

*Regulators before revenue; receipts before features.*

The bench has done its work. Tomorrow: open the restaurant.
