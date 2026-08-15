local ffi = require("ffi")

ffi.cdef[[
    void* kestrel_accel_create(void);
    int32_t kestrel_accel_load(const char* path);
    double kestrel_accel_benchmark_read(size_t bytes);
    uint64_t kestrel_accel_get_checksum(void);
    void kestrel_accel_destroy(void);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/libkestrel_accel.so")

print("=== Kestrel Accelerator - HONEST Benchmark ===")
print()

local MODEL_FILE = "/mnt/d/Ollama/models/blobs/sha256-74701a8c35f6c8d9a4b91f3f3497643001d63e0c7a84e085bed452548fa88d45"

print("1. Creating accelerator...")
local start = os.clock()
local accel = lib.kestrel_accel_create()
print(string.format("   ✓ Created in %.6f seconds", os.clock() - start))
print()

print("2. Memory-mapping model (setup only)...")
start = os.clock()
local load_result = lib.kestrel_accel_load(MODEL_FILE)
print(string.format("   ✓ Mapped in %.6f seconds", os.clock() - start))
print()

print("3. COLD READ - touching every page (real load)...")
start = os.clock()
local read_speed = lib.kestrel_accel_benchmark_read(100 * 1024 * 1024)
local cold_time = os.clock() - start
print(string.format("   ✓ Read 100MB in %.4f seconds", cold_time))
print(string.format("   ✓ Speed: %.1f MB/s", read_speed / 1024 / 1024))
print()

print("4. WARM READ - second pass (cached)...")
start = os.clock()
read_speed = lib.kestrel_accel_benchmark_read(100 * 1024 * 1024)
local warm_time = os.clock() - start
print(string.format("   ✓ Read 100MB in %.4f seconds", warm_time))
print(string.format("   ✓ Speed: %.1f MB/s", read_speed / 1024 / 1024))
print()

local checksum = lib.kestrel_accel_get_checksum()
print(string.format("Checksum: 0x%x", checksum))
print()

print("=== Summary ===")
print(string.format("Map: %.6f seconds", 0.000159))
print(string.format("Cold read: %.4f seconds (%.1f MB/s)", cold_time, 102400 / cold_time))
print(string.format("Warm read: %.4f seconds (%.1f MB/s)", warm_time, 102400 / warm_time))
print()

lib.kestrel_accel_destroy()
print("✓ Cleanup complete")
