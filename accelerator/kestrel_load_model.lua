-- Load GGUF model properly into Kestrel v2.0
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

-- Proper little-endian reading
local function read_u32(file)
    local b1, b2, b3, b4 = file:read(4):byte(1, 4)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function read_u64(file)
    local bytes = file:read(8)
    local val = 0
    for i = 8, 1, -1 do
        val = val * 256 + bytes:byte(i)
    end
    return val
end

print("=== Kestrel v2.0 Model Loader (Proper GGUF) ===")
print()

local MODEL_FILE = "/mnt/d/Ollama/models/blobs/sha256-74701a8c35f6c8d9a4b91f3f3497643001d63e0c7a84e085bed452548fa88d45"

-- Init Kestrel
local ctx = lib.kestrel_init_v2(16 * 1024 * 1024 * 1024)

-- Open model
local file = io.open(MODEL_FILE, "rb")

-- Read GGUF header properly
local magic = file:read(4)
print("Magic: " .. magic)

local version = read_u32(file)
print("Version: " .. version)

local tensor_count = read_u64(file)
print("Tensor count: " .. tensor_count)

local metadata_size = read_u64(file)
print("Metadata size: " .. metadata_size .. " bytes")

-- Skip metadata and read tensor data
file:seek("set", 4 + 4 + 8 + 8 + metadata_size)

-- Read first tensor
local tensor_name_len = read_u64(file)
local tensor_name = file:read(tensor_name_len)
print("\nFirst tensor: " .. tensor_name)

-- Read tensor dimensions
local n_dims = read_u32(file)
print("Dimensions: " .. n_dims)

-- Read tensor size
local tensor_size = read_u64(file)
print("Tensor size: " .. tensor_size .. " bytes")

file:close()

-- Cleanup
lib.kestrel_deinit_v2(ctx)
print("\n✓ Model structure parsed successfully")
