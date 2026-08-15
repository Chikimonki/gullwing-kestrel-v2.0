# Kestrel-Gullwing Integration Plan

## Architecture Overview
Kestrel v2.0 becomes the embedded inference engine for Gullwing's binary analysis.

## Integration Points

### 1. Binary Analysis Enhancement
- Static analysis results feed into Kestrel router
- Expert models analyze specific binary features
- Convergent verdict combines multiple expert opinions

### 2. Memory-Efficient Processing
- 25GB budget allows full binary analysis in-memory
- Ring buffers stream large binaries
- Zero-copy FFI eliminates serialization overhead

### 3. Real-Time Threat Detection
- Hot experts (loaded in memory) handle common threats
- Cold experts (streamed from disk) handle rare cases
- Sub-μs routing enables real-time analysis

## Next Steps
1. Implement ring buffer in bridge.zig
2. Add expert weight loading from files
3. Create Gullwing analysis experts
4. Benchmark against original implementation
