
Contribution Offer: LuaJIT Policy Layer for Colibri
Summary
We've built a hot-swappable routing policy layer using Zig + LuaJIT FFI that aligns with colibri's "measurable policies rather than promises" principle. It allows runtime A/B testing of routing strategies without recompiling.

What We're Offering
Kernel evidence: Zig AVX2 achieves 2.97x over scalar on int8 quantized matmul with numerical parity at 9.5e-5

Policy layer: 4 routing policies (balanced, greedy, diverse, cache-aware) switchable at runtime in 0.108μs

Storage measurements: Honest hybrid tier speeds (565/162 MB/s)

Benchmark discipline: Standing rules that caught 4 of our own measurement errors

The Novel Contribution
Colibri's README asks experimenters to "change one variable, repeat the run." Our LuaJIT policy layer makes this instant — no recompile, no restart.

Request
Would the maintainers be interested in this as a contribution? We believe the policy layer concept serves every colibri user.

License
MIT — same as colibri.
