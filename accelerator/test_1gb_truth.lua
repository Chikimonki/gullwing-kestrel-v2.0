local ffi = require("ffi")

ffi.cdef[[
    void* kestrel_accel_create(void);
    int32_t kestrel_accel_load(const char* path);
    double kestrel_accel_benchmark_read(size_t bytes);
    uint64_t kestrel_accel_get_checksum(void);
    size_t kestrel_accel_get_bytes_touched(void);
    void kestrel_accel_destroy(void);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/libkestrel_accel.so")

print("=== DEFINITIVE 1GB TRUTH BENCHMARK ===")
print()

local tests = {
    {name = "1. Inside VM (ext4)", path = os.getenv("HOME") .. "/bench_1gb_fresh.bin"},
    {name = "2. D: HDD (fresh 1GB)", path = "/mnt/d/test_kestrel_1gb_fresh.bin"},
}

for _, test in ipairs(tests) do
    print(test.name .. ":")
    
    lib.kestrel_accel_create()
    local ok = lib.kestrel_accel_load(test.path)
    
    if ok ~= 0 then
        print("  ✗ Load failed")
        lib.kestrel_accel_destroy()
        print()
        goto continue
    end
    
    local start = os.clock()
    local speed = lib.kestrel_accel_benchmark_read(1024 * 1024 * 1024)  -- 1GB
    local elapsed = os.clock() - start
    
    local bytes_touched = lib.kestrel_accel_get_bytes_touched()
    local checksum = lib.kestrel_accel_get_checksum()
    
    print(string.format("  Time: %.4f seconds", elapsed))
    print(string.format("  Bytes touched: %d", bytes_touched))
    print(string.format("  Speed: %.1f MB/s", speed))
    print(string.format("  Checksum: 0x%x", checksum))
    
    lib.kestrel_accel_destroy()
    print()
    
    ::continue::
end

print("=== TRUTH REVEALED ===")
