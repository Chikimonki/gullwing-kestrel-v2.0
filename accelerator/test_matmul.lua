local ffi = require("ffi")

ffi.cdef[[
    void kestrel_matvec(
        const float* weights,
        const float* input,
        float* output,
        size_t input_dim,
        size_t output_dim,
        bool use_simd
    );
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/libmatmul.so")

print("=== Matrix Multiplication Benchmark ===")
print()

-- Test dimensions (like a small transformer layer)
local input_dim = 2048
local output_dim = 2048

-- Allocate test data
local weights = ffi.new("float[?]", input_dim * output_dim)
local input = ffi.new("float[?]", input_dim)
local output = ffi.new("float[?]", output_dim)

-- Fill with random data
for i = 0, input_dim * output_dim - 1 do
    weights[i] = math.random() * 0.1
end
for i = 0, input_dim - 1 do
    input[i] = math.random()
end

-- Benchmark scalar version
print("1. Scalar matvec...")
local start = os.clock()
for iter = 1, 10 do
    lib.kestrel_matvec(weights, input, output, input_dim, output_dim, false)
end
local scalar_time = os.clock() - start
print(string.format("   ✓ 10 iterations: %.4f seconds", scalar_time))
print(string.format("   ✓ Per iteration: %.4f ms", scalar_time * 100))
print()

-- Benchmark SIMD version
print("2. SIMD matvec...")
start = os.clock()
for iter = 1, 10 do
    lib.kestrel_matvec(weights, input, output, input_dim, output_dim, true)
end
local simd_time = os.clock() - start
print(string.format("   ✓ 10 iterations: %.4f seconds", simd_time))
print(string.format("   ✓ Per iteration: %.4f ms", simd_time * 100))
print()

-- Comparison
local speedup = scalar_time / simd_time
print(string.format("=== SIMD Speedup: %.2fx ===", speedup))
