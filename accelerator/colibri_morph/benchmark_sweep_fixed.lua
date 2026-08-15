local ffi = require("ffi")

ffi.cdef[[
    void zig_matmul(float* y, const float* x, const float* W, size_t S, size_t I, size_t O);
    void scalar_matmul(float* y, const float* x, const float* W, size_t S, size_t I, size_t O);
    int32_t known_answer_test(void);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/colibri_morph/libmatmul_zig.so")

-- Known answer first
assert(lib.known_answer_test() == 0, "Known-answer test failed")

print("=== Matmul Sweep (FIXED - K loop verified) ===")
print()

local sizes = {
    {name = "Small (64x64x64)", S=1, I=64, O=64, iters=500},
    {name = "Medium (512x512x512)", S=1, I=512, O=512, iters=50},
    {name = "Large (2048x2048x2048)", S=1, I=2048, O=2048, iters=5},
    {name = "Batch (4x1024x1024)", S=4, I=1024, O=1024, iters=10},
}

for _, sz in ipairs(sizes) do
    print(sz.name .. ":")
    
    local y1 = ffi.new("float[?]", sz.S * sz.O)
    local y2 = ffi.new("float[?]", sz.S * sz.O)
    local x = ffi.new("float[?]", sz.S * sz.I)
    local W = ffi.new("float[?]", sz.O * sz.I)
    
    for i = 0, sz.S * sz.I - 1 do x[i] = math.random() end
    for i = 0, sz.O * sz.I - 1 do W[i] = math.random() * 0.1 end
    
    -- Warm up
    lib.scalar_matmul(y1, x, W, sz.S, sz.I, sz.O)
    lib.zig_matmul(y2, x, W, sz.S, sz.I, sz.O)
    
    -- Benchmark scalar
    local start = os.clock()
    for iter = 1, sz.iters do
        lib.scalar_matmul(y1, x, W, sz.S, sz.I, sz.O)
    end
    local scalar_time = (os.clock() - start) / sz.iters * 1000
    
    -- Benchmark Zig
    start = os.clock()
    for iter = 1, sz.iters do
        lib.zig_matmul(y2, x, W, sz.S, sz.I, sz.O)
    end
    local zig_time = (os.clock() - start) / sz.iters * 1000
    
    -- REAL GFLOPS: 2 * S * I * O
    local flops = 2 * sz.S * sz.I * sz.O
    local scalar_gflops = flops / (scalar_time / 1000) / 1e9
    local zig_gflops = flops / (zig_time / 1000) / 1e9
    
    local speedup = scalar_time / zig_time
    
    print(string.format("  Scalar: %.4f ms (%.2f GFLOPS)", scalar_time, scalar_gflops))
    print(string.format("  Zig:    %.4f ms (%.2f GFLOPS)", zig_time, zig_gflops))
    print(string.format("  Speedup: %.2fx", speedup))
    print()
end
