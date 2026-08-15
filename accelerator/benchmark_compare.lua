-- Compare Ollama vs Kestrel v2.0 for existing models
local ffi = require("ffi")

ffi.cdef[[
    typedef struct KestrelContext {
        size_t total_memory;
        size_t used_memory;
        bool initialized;
        uint32_t num_experts;
    } KestrelContext;
    
    KestrelContext* kestrel_init_v2(size_t total_memory);
    void kestrel_deinit_v2(KestrelContext* ctx);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/libkestrel_v2.so")

print("=== Kestrel v2.0 vs Ollama Benchmark ===")
print()

-- Ollama baseline (measured earlier)
print("Ollama Baselines (measured):")
print("  Llama 3.2 1B: 0.2 tok/s (39.85s for 8 tokens)")
print("  Phi4-mini:    2.75 tok/s (25.45s for 70 tokens)")
print()

-- Kestrel initialization benchmark
print("Kestrel v2.0 Init Benchmark:")
local start = os.clock()
local ctx = lib.kestrel_init_v2(16 * 1024 * 1024 * 1024)
local init_time = os.clock() - start
print(string.format("  Init time: %.6f seconds", init_time))
print(string.format("  Memory: %d MB", tonumber(ctx.used_memory) / 1024 / 1024))
print()

-- Cleanup
lib.kestrel_deinit_v2(ctx)
print("=== Benchmark Complete ===")
