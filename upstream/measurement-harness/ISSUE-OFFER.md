# Contribution Offer: Measurement Harness for Colibri

## Summary
A benchmark suite and measurement discipline developed during the Kestrel v2.0 campaign. Every number reconciles; every claim has a receipt.

## What We're Offering
1. Honest storage benchmark (cold/warm separation, byte counting, checksums)
2. SIMD vs scalar comparison (with compiler-elimination protection)
3. Recognition cache benchmark
4. Standing rules that prevent the "petabyte fantasy" class of errors

## Key Findings That May Help Colibri
- WSL2 bridge caps drive access at ~195 MB/s
- VM ext4 achieves 565-1103 MB/s (recommended for hot tier)
- mmap loading should be described as "deferred to first touch" not "faster"

## Request
Would the maintainers be interested in this harness as a contribution? We believe it serves every colibri user and asks nothing in return.

## License
MIT — same as colibri.
