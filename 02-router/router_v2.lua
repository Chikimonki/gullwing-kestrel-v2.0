-- router_v2.lua — Router with real expert weights
local ffi = require("ffi")

ffi.cdef[[
    typedef struct KestrelContext {
        size_t total_memory;
        size_t used_memory;
        bool initialized;
        uint32_t num_experts;
    } KestrelContext;
    
    typedef struct ExpertHandle {
        uint32_t expert_id;
        size_t input_dim;
        size_t output_dim;
        bool hot;
        void* weights_ptr;
    } ExpertHandle;
    
    KestrelContext* kestrel_init_v2(size_t total_memory);
    void kestrel_deinit_v2(KestrelContext* ctx);
    
    ExpertHandle* kestrel_create_expert(
        KestrelContext* ctx,
        uint32_t expert_id,
        size_t input_dim,
        size_t output_dim,
        bool hot
    );
    
    int32_t kestrel_load_expert_file(
        ExpertHandle* handle,
        const char* path
    );
    
    int32_t kestrel_forward_v2(
        KestrelContext* ctx,
        ExpertHandle* handle,
        const float* input,
        size_t input_len,
        float* output,
        size_t output_len
    );
    
    void kestrel_get_expert_info(
        ExpertHandle* handle,
        size_t* input_dim,
        size_t* output_dim,
        bool* hot
    );
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/libkestrel_v2.so")

local RouterV2 = {
    ctx = nil,
    experts = {},
    initialized = false,
}

function RouterV2.init(total_memory)
    if RouterV2.initialized then return end
    
    RouterV2.ctx = lib.kestrel_init_v2(total_memory or 16 * 1024 * 1024 * 1024)
    assert(RouterV2.ctx ~= nil, "Failed to initialize")
    
    RouterV2.initialized = true
    print(string.format("✓ Router v2 initialized (%.1f GB budget)", 
          tonumber(RouterV2.ctx.total_memory) / 1024 / 1024 / 1024))
end

function RouterV2.create_expert(expert_id, input_dim, output_dim, hot)
    local handle = lib.kestrel_create_expert(
        RouterV2.ctx,
        expert_id,
        input_dim,
        output_dim,
        hot or false
    )
    
    if handle == nil then
        error("Failed to create expert " .. expert_id)
    end
    
    RouterV2.experts[expert_id] = {
        handle = handle,
        input_dim = input_dim,
        output_dim = output_dim,
        hot = hot or false,
    }
    
    print(string.format("✓ Created expert %d (%d→%d, %s)", 
          expert_id, input_dim, output_dim, hot and "hot" or "cold"))
    
    return handle
end

function RouterV2.forward(expert_id, input_table)
    local expert = RouterV2.experts[expert_id]
    if not expert then
        error("Expert not found: " .. expert_id)
    end
    
    -- Convert input table to C array
    local input = ffi.new("float[?]", #input_table)
    for i = 1, #input_table do
        input[i - 1] = input_table[i]
    end
    
    -- Allocate output
    local output = ffi.new("float[?]", expert.output_dim)
    
    -- Run forward pass
    local ret = lib.kestrel_forward_v2(
        RouterV2.ctx,
        expert.handle,
        input,
        #input_table,
        output,
        expert.output_dim
    )
    
    if ret ~= 0 then
        return nil, "Forward pass failed"
    end
    
    -- Convert output to Lua table
    local result = {}
    for i = 0, expert.output_dim - 1 do
        result[i + 1] = output[i]
    end
    
    return result
end

function RouterV2.deinit()
    if RouterV2.ctx then
        lib.kestrel_deinit_v2(RouterV2.ctx)
        RouterV2.ctx = nil
    end
    RouterV2.experts = {}
    RouterV2.initialized = false
end

return RouterV2
