local ffi = require("ffi")

ffi.cdef[[
    void* kestrel_accel_create(void);
    int32_t kestrel_accel_load(const char* path);
    double kestrel_accel_benchmark_read(size_t bytes);
    uint64_t kestrel_accel_get_checksum(void);
    void kestrel_accel_destroy(void);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/libkestrel_accel.so")

print("=== THREE-WAY STORAGE BENCHMARK ===")
print()

local test_files = {
    {name = "Inside VM (ext4 on NVMe)", path = os.getenv("HOME") .. "/bench.tmp"},
    {name = "C: NVMe (via bridge)", path = "/mnt/c/bench.tmp"},
    {name = "D: HDD (via bridge)", path = "/mnt/d/bench.tmp"},
}

for _, test in ipairs(test_files) do
    print(test.name .. ":")
    
    -- Check file exists
    local f = io.open(test.path, "rb")
    if not f then
        print("  ✗ File not found")
        print()
        goto continue
    end
    f:close()
    
    -- Map
    lib.kestrel_accel_create()
    local load_ok = lib.kestrel_accel_load(test.path)
    
    if load_ok ~= 0 then
        print("  ✗ Map failed")
        lib.kestrel_accel_destroy()
        print()
        goto continue
    end
    
    -- Cold read
    local start = os.clock()
    local speed = lib.kestrel_accel_benchmark_read(100 * 1024 * 1024)
    local elapsed = os.clock() - start
    
    if speed < 0 then
        print("  ✗ Read failed")
    else
        print(string.format("  Cold: %.4f s = %.1f MB/s", elapsed, speed))
    end
    
    lib.kestrel_accel_destroy()
    print()
    
    ::continue::
end

print("=== DONE ===")
