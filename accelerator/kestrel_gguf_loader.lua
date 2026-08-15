-- kestrel_gguf_loader.lua — Load GGUF model directly into Kestrel
local ffi = require("ffi")

ffi.cdef[[
    typedef struct KestrelContext {
        size_t total_memory;
        size_t used_memory;
        bool initialized;
        uint32_t num_experts;
    } KestrelContext;
    
    KestrelContext* kestrel_init_v2(size_t total_memory);
    void kestrel_deinit_v2(KestrelContext* ctx);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/libkestrel_v2.so")

print("=== Kestrel v2.0 GGUF Model Loader ===")
print()

-- Model file details
local MODEL_FILE = "/mnt/d/Ollama/models/blobs/sha256-74701a8c35f6c8d9a4b91f3f3497643001d63e0c7a84e085bed452548fa88d45"
local MODEL_SIZE = 1321082688  -- 1.32GB

-- Initialize Kestrel
print("1. Initializing Kestrel...")
local start = os.clock()
local ctx = lib.kestrel_init_v2(16 * 1024 * 1024 * 1024)
local init_time = os.clock() - start
print(string.format("   ✓ Init: %.6f seconds (%.2f μs)", init_time, init_time * 1000000))
print()

-- Read model file header
print("2. Reading GGUF header...")
local file = io.open(MODEL_FILE, "rb")
if not file then
    print("   ✗ Could not open model file")
    return
end

-- Read GGUF magic (first 4 bytes should be "GGUF")
local magic = file:read(4)
print(string.format("   Magic: %s", magic))

-- Read version (4 bytes)
local version = file:read(4)
local version_num = 0
for i = 1, 4 do
    version_num = version_num * 256 + version:byte(i)
end
print(string.format("   Version: %d", version_num))

-- Read tensor count (8 bytes)
local tensor_count_bytes = file:read(8)
local tensor_count = 0
for i = 1, 8 do
    tensor_count = tensor_count * 256 + tensor_count_bytes:byte(i)
end
print(string.format("   Tensors: %d", tensor_count))

-- Read metadata size (8 bytes)
local meta_size_bytes = file:read(8)
local meta_size = 0
for i = 1, 8 do
    meta_size = meta_size * 256 + meta_size_bytes:byte(i)
end
print(string.format("   Metadata: %d bytes", meta_size))

file:close()
print()

-- Benchmark file read speed (what we're up against)
print("3. Benchmarking file read speed...")
file = io.open(MODEL_FILE, "rb")
local chunk_size = 1024 * 1024  -- 1MB chunks
local total_read = 0
local start_read = os.clock()

while total_read < 100 * 1024 * 1024 do  -- Read first 100MB
    local chunk = file:read(chunk_size)
    if not chunk then break end
    total_read = total_read + #chunk
end

local read_time = os.clock() - start_read
file:close()

local read_speed = (total_read / 1024 / 1024) / read_time
print(string.format("   ✓ Read %d MB in %.3f seconds", total_read / 1024 / 1024, read_time))
print(string.format("   ✓ Speed: %.1f MB/s", read_speed))
print()

-- Summary
print("=== Summary ===")
print(string.format("Kestrel init: %.6f seconds", init_time))
print(string.format("File read speed: %.1f MB/s", read_speed))
print(string.format("Model size: %.2f GB", MODEL_SIZE / 1024 / 1024 / 1024))
print()

-- Cleanup
lib.kestrel_deinit_v2(ctx)
print("✓ Cleanup complete")
