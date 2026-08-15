-- storage_policy.lua — Hybrid storage: pin hot on NVMe, stream cold from HDD
local ffi = require("ffi")

ffi.cdef[[
    void* kestrel_accel_create(void);
    int32_t kestrel_accel_load(const char* path);
    double kestrel_accel_benchmark_read(size_t bytes);
    uint64_t kestrel_accel_get_checksum(void);
    void kestrel_accel_destroy(void);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/libkestrel_accel.so")

print("=== Hybrid Storage Policy ===")
print()

-- Your actual storage tiers
local TIERS = {
    NVME = {
        path = "/mnt/c",
        free_gb = 7.5,
        speed_mbps = 195,  -- Measured cold read
        usage = "hot experts",
    },
    HDD = {
        path = "/mnt/d",
        free_gb = 122,
        speed_mbps = 195,  -- Same for now (measured)
        usage = "cold experts",
    },
}

-- Policy: what goes where
local POLICY = {
    hot_threshold_gb = 2,  -- Models under 2GB go to NVMe
    hot_expert_count = 4,  -- First 4 experts are hot
    cold_stream_chunk_mb = 16,  -- Stream cold experts in 16MB chunks
}

print("Storage Tiers:")
for name, tier in pairs(TIERS) do
    print(string.format("  %s: %s (%d GB free, %d MB/s, %s)", 
          name, tier.path, tier.free_gb, tier.speed_mbps, tier.usage))
end
print()

print("Policy:")
print(string.format("  Hot threshold: %d GB", POLICY.hot_threshold_gb))
print(string.format("  Hot experts: %d", POLICY.hot_expert_count))
print(string.format("  Cold stream chunk: %d MB", POLICY.cold_stream_chunk_mb))
print()

-- Test loading from each tier
print("Testing load speeds from each tier...")
print()

-- NVMe test (C:)
local nvme_file = "/mnt/c/test_kestrel_speed.bin"
print("NVMe (C:) cold read:")
local start = os.clock()
lib.kestrel_accel_create()
lib.kestrel_accel_load(nvme_file)
local speed = lib.kestrel_accel_benchmark_read(50 * 1024 * 1024)
print(string.format("  ✓ %.1f MB/s", speed / 1024 / 1024))
lib.kestrel_accel_destroy()
print()

-- HDD test (D:)
local hdd_file = "/mnt/d/Ollama/models/blobs/sha256-74701a8c35f6c8d9a4b91f3f3497643001d63e0c7a84e085bed452548fa88d45"
print("HDD (D:) cold read:")
start = os.clock()
lib.kestrel_accel_create()
lib.kestrel_accel_load(hdd_file)
speed = lib.kestrel_accel_benchmark_read(50 * 1024 * 1024)
print(string.format("  ✓ %.1f MB/s", speed / 1024 / 1024))
lib.kestrel_accel_destroy()
print()

print("=== Hybrid Storage Policy Ready ===")
print("Next: Route experts based on this policy")
