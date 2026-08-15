local ffi = require("ffi")

ffi.cdef[[
    void* kestrel_accel_create(void);
    int32_t kestrel_accel_load(const char* path);
    double kestrel_accel_benchmark_read(size_t bytes);
    uint64_t kestrel_accel_get_checksum(void);
    void kestrel_accel_destroy(void);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/libkestrel_accel.so")

print("=== HONEST D: Drive Benchmark ===")
print()

local D_FILE = "/mnt/d/test_kestrel_100mb.bin"

-- Test 1: Map
print("1. Memory-mapping...")
local start = os.clock()
lib.kestrel_accel_create()
lib.kestrel_accel_load(D_FILE)
local map_time = os.clock() - start
print(string.format("   Map time: %.6f seconds", map_time))
print()

-- Test 2: Cold read (first pass)
print("2. COLD read (from D: HDD)...")
start = os.clock()
local cold_speed = lib.kestrel_accel_benchmark_read(100 * 1024 * 1024)
local cold_time = os.clock() - start
print(string.format("   Time: %.4f seconds", cold_time))
print(string.format("   Speed: %.1f MB/s", cold_speed))
print()

-- Test 3: Warm read (second pass, cached)
print("3. WARM read (from RAM cache)...")
start = os.clock()
local warm_speed = lib.kestrel_accel_benchmark_read(100 * 1024 * 1024)
local warm_time = os.clock() - start
print(string.format("   Time: %.4f seconds", warm_time))
print(string.format("   Speed: %.1f MB/s", warm_speed))
print()

print(string.format("Checksum: 0x%x", lib.kestrel_accel_get_checksum()))
print()
print("=== HONEST RESULTS ===")
print(string.format("Map: %.6f s", map_time))
print(string.format("Cold (D:): %.4f s = %.1f MB/s", cold_time, cold_speed))
print(string.format("Warm (RAM): %.4f s = %.1f MB/s", warm_time, warm_speed))

lib.kestrel_accel_destroy()
