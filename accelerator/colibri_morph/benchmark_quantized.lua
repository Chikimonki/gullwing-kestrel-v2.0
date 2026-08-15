local ffi = require("ffi")

ffi.cdef[[
    void scalar_matmul_q(float* y, const float* x, const int8_t* q, const float* scale, size_t I, size_t O);
    void zig_matmul_q(float* y, const float* x, const int8_t* q, const float* scale, size_t I, size_t O);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/colibri_morph/libmatmul_q.so")

print("=== Quantized Matmul: Scalar vs Zig ===")
print()

local I = 2048
local O = 2048

local y1 = ffi.new("float[?]", O)
local y2 = ffi.new("float[?]", O)
local x = ffi.new("float[?]", I)
local q = ffi.new("int8_t[?]", O * I)
local scale = ffi.new("float[?]", O)

for i = 0, I - 1 do x[i] = math.random() end
for i = 0, O * I - 1 do q[i] = math.random(-128, 127) end
for i = 0, O - 1 do scale[i] = 0.01 end

-- Warm up
lib.scalar_matmul_q(y1, x, q, scale, I, O)
lib.zig_matmul_q(y2, x, q, scale, I, O)

print("1. Scalar quantized...")
local start = os.clock()
for iter = 1, 20 do
    lib.scalar_matmul_q(y1, x, q, scale, I, O)
end
local scalar_time = os.clock() - start
print(string.format("   20 iterations: %.4f s", scalar_time))
print(string.format("   Per iteration: %.4f ms", scalar_time * 50))
print()

print("2. Zig quantized...")
start = os.clock()
for iter = 1, 20 do
    lib.zig_matmul_q(y2, x, q, scale, I, O)
end
local zig_time = os.clock() - start
print(string.format("   20 iterations: %.4f s", zig_time))
print(string.format("   Per iteration: %.4f ms", zig_time * 50))
print()

-- Verify
local max_diff = 0
for i = 0, O - 1 do
    local diff = math.abs(y1[i] - y2[i])
    if diff > max_diff then max_diff = diff end
end
print(string.format("Max difference: %.6f", max_diff))
print()

local speedup = scalar_time / zig_time
print(string.format("=== Zig Speedup: %.2fx ===", speedup))
