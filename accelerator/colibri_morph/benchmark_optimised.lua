local ffi = require("ffi")

ffi.cdef[[
    void scalar_matmul(float* y, const float* x, const float* W, size_t S, size_t I, size_t O);
    void zig_matmul_fma(float* y, const float* x, const float* W, size_t S, size_t I, size_t O);
    void zig_matmul_blocked(float* y, const float* x, const float* W, size_t S, size_t I, size_t O);
]]

local lib_orig = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/colibri_morph/libmatmul_zig.so")
local lib_opt = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/colibri_morph/libmatmul_opt.so")

print("=== Optimised Matmul: Scalar vs FMA vs Blocked ===")
print()

local S = 1
local I = 2048
local O = 2048

local y1 = ffi.new("float[?]", S * O)
local y2 = ffi.new("float[?]", S * O)
local y3 = ffi.new("float[?]", S * O)
local x = ffi.new("float[?]", S * I)
local W = ffi.new("float[?]", O * I)

for i = 0, S * I - 1 do x[i] = math.random() end
for i = 0, O * I - 1 do W[i] = math.random() * 0.1 end

-- Warm up
lib_orig.scalar_matmul(y1, x, W, S, I, O)
lib_opt.zig_matmul_fma(y2, x, W, S, I, O)
lib_opt.zig_matmul_blocked(y3, x, W, S, I, O)

print("1. Scalar...")
local start = os.clock()
for iter = 1, 20 do
    lib_orig.scalar_matmul(y1, x, W, S, I, O)
end
local scalar_time = (os.clock() - start) / 20 * 1000
print(string.format("   %.4f ms", scalar_time))
print()

print("2. Zig FMA...")
start = os.clock()
for iter = 1, 20 do
    lib_opt.zig_matmul_fma(y2, x, W, S, I, O)
end
local fma_time = (os.clock() - start) / 20 * 1000
print(string.format("   %.4f ms (%.2fx vs scalar)", fma_time, scalar_time / fma_time))
print()

print("3. Zig Blocked...")
start = os.clock()
for iter = 1, 20 do
    lib_opt.zig_matmul_blocked(y3, x, W, S, I, O)
end
local blocked_time = (os.clock() - start) / 20 * 1000
print(string.format("   %.4f ms (%.2fx vs scalar)", blocked_time, scalar_time / blocked_time))
print()

-- Verify correctness
local max_diff_fma = 0
local max_diff_blocked = 0
for i = 0, S * O - 1 do
    local df = math.abs(y1[i] - y2[i])
    local db = math.abs(y1[i] - y3[i])
    if df > max_diff_fma then max_diff_fma = df end
    if db > max_diff_blocked then max_diff_blocked = db end
end
print(string.format("FMA max diff: %.6f", max_diff_fma))
print(string.format("Blocked max diff: %.6f", max_diff_blocked))
