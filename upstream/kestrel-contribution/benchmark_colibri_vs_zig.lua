local ffi = require("ffi")

ffi.cdef[[
    void zig_matmul(float* y, const float* x, const float* W, size_t S, size_t I, size_t O);
    void scalar_matmul(float* y, const float* x, const float* W, size_t S, size_t I, size_t O);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/colibri_morph/libmatmul_zig.so")

print("=== Colibri-style vs Zig matmul ===")
print()

local S = 1
local I = 2048
local O = 2048

local y_zig = ffi.new("float[?]", S * O)
local y_scalar = ffi.new("float[?]", S * O)
local x = ffi.new("float[?]", S * I)
local W = ffi.new("float[?]", O * I)

for i = 0, S * I - 1 do x[i] = math.random() end
for i = 0, O * I - 1 do W[i] = math.random() * 0.1 end

-- Warm up
lib.scalar_matmul(y_scalar, x, W, S, I, O)
lib.zig_matmul(y_zig, x, W, S, I, O)

print("1. Scalar matmul (colibri-style)...")
local start = os.clock()
for iter = 1, 20 do
    lib.scalar_matmul(y_scalar, x, W, S, I, O)
end
local scalar_time = os.clock() - start
print(string.format("   20 iterations: %.4f s", scalar_time))
print(string.format("   Per iteration: %.4f ms", scalar_time * 50))
print()

print("2. Zig AVX2 matmul...")
start = os.clock()
for iter = 1, 20 do
    lib.zig_matmul(y_zig, x, W, S, I, O)
end
local zig_time = os.clock() - start
print(string.format("   20 iterations: %.4f s", zig_time))
print(string.format("   Per iteration: %.4f ms", zig_time * 50))
print()

local max_diff = 0
for i = 0, S * O - 1 do
    local diff = math.abs(y_scalar[i] - y_zig[i])
    if diff > max_diff then max_diff = diff end
end
print(string.format("Max difference: %.6f", max_diff))
print()

local speedup = scalar_time / zig_time
print(string.format("=== Zig Speedup: %.2fx ===", speedup))
