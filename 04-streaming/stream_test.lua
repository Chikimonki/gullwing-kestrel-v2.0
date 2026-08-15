-- Test ring buffer integration with LuaJIT
local ffi = require("ffi")

ffi.cdef[[
    typedef struct KestrelContext {
        size_t total_memory;
        size_t used_memory;
        bool initialized;
        void* ring_buffer;
    } KestrelContext;
    
    typedef struct ExpertHandle {
        uint32_t expert_id;
        size_t size;
        bool hot;
        int64_t last_access;
        uint64_t access_count;
    } ExpertHandle;
    
    typedef struct StreamHandle {
        size_t buffer_size;
        size_t bytes_processed;
        void* ring_buffer;
    } StreamHandle;
    
    KestrelContext* kestrel_init_enhanced(
        size_t total_memory,
        size_t ring_buffer_size
    );
    
    int32_t kestrel_stream_expert(
        KestrelContext* ctx,
        uint32_t expert_id,
        const uint8_t* data,
        size_t len
    );
    
    int32_t kestrel_read_stream(
        KestrelContext* ctx,
        uint8_t* output,
        size_t max_len
    );
    
    size_t kestrel_get_buffer_stats(KestrelContext* ctx);
]]

local lib = ffi.load("./libkestrel_enhanced.so")

print("=== Ring Buffer Integration Test ===\n")

-- Initialize with ring buffer
local ctx = lib.kestrel_init_enhanced(1024 * 1024 * 1024, 64 * 1024)
assert(ctx ~= nil, "Failed to initialize")

print("✓ Context initialized with ring buffer")
print(string.format("  Ring buffer available: %d bytes", 
      tonumber(lib.kestrel_get_buffer_stats(ctx))))
print()

-- Stream expert data
print("Streaming expert data...")
local data = ffi.new("uint8_t[?]", 4096)
for i = 0, 4095 do
    data[i] = i % 256
end

local written = lib.kestrel_stream_expert(ctx, 1, data, 4096)
print(string.format("✓ Streamed %d bytes", written))
print(string.format("  Buffer available: %d bytes", 
      tonumber(lib.kestrel_get_buffer_stats(ctx))))
print()

-- Read streamed data
print("Reading streamed data...")
local output = ffi.new("uint8_t[?]", 4096)
local read = lib.kestrel_read_stream(ctx, output, 4096)
print(string.format("✓ Read %d bytes", read))

-- Verify data integrity
local matches = true
for i = 0, read - 1 do
    if output[i] ~= data[i] then
        matches = false
        print(string.format("✗ Mismatch at byte %d: expected %d, got %d", 
              i, data[i], output[i]))
        break
    end
end

if matches then
    print("✓ Data integrity verified - all bytes match")
end
print()

print("=== Ring Buffer Test Complete ===")
