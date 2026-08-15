-- router.lua — JIT-compiled MoE routing hot path
local ffi = require("ffi")

-- C ABI definitions (matching Zig structs exactly)
ffi.cdef[[
    typedef struct KestrelContext {
        size_t total_memory;
        size_t used_memory;
        bool initialized;
    } KestrelContext;
    
    typedef struct ExpertHandle {
        uint32_t expert_id;
        size_t size;
        bool hot;
    } ExpertHandle;
    
    typedef struct StreamHandle {
        size_t buffer_size;
        size_t bytes_processed;
    } StreamHandle;
    
    KestrelContext* kestrel_init(size_t total_memory);
    void kestrel_deinit(KestrelContext* ctx);
    
    ExpertHandle* kestrel_load_expert(
        KestrelContext* ctx,
        uint32_t expert_id,
        const uint8_t* data,
        size_t len,
        bool hot
    );
    
    void kestrel_unload_expert(ExpertHandle* handle);
    
    int32_t kestrel_forward(
        KestrelContext* ctx,
        uint32_t expert_id,
        const float* input,
        size_t input_len,
        float* output,
        size_t output_len
    );
    
    StreamHandle* kestrel_stream_create(
        KestrelContext* ctx,
        size_t buffer_size
    );
    
    int32_t kestrel_stream_push(
        StreamHandle* stream,
        const uint8_t* data,
        size_t len
    );
    
    int32_t kestrel_stream_pop(
        StreamHandle* stream,
        uint8_t* output,
        size_t max_len
    );
    
    size_t kestrel_get_memory_usage(KestrelContext* ctx);
    void kestrel_reset_arena(KestrelContext* ctx);
]]

-- Load shared library
local function load_library()
    local paths = {
        "./libkestrel.so",
        "../libkestrel.so",
        "../../libkestrel.so",
        "/mnt/d/moabi/gullwing-kestrel/libkestrel.so",
    }
    
    for _, path in ipairs(paths) do
        local ok, lib = pcall(ffi.load, path)
        if ok then
            return lib
        end
    end
    
    error("Could not load libkestrel.so. Please run ./build.sh first.")
end

local lib = load_library()

-- Router configuration
local Router = {
    num_experts = 8,
    top_k = 2,
    experts = {},
    ctx = nil,
    initialized = false,
}

-- Initialize router
function Router.init(total_memory)
    if Router.initialized then
        return
    end
    
    Router.ctx = lib.kestrel_init(total_memory or 25 * 1024 * 1024 * 1024)
    if Router.ctx == nil then
        error("Failed to initialize Kestrel context")
    end
    
    Router.initialized = true
    print(string.format("✓ Router initialized (%.1f GB budget)", 
          tonumber(Router.ctx.total_memory) / 1024 / 1024 / 1024))
end

-- Load expert weights
function Router.load_expert(expert_id, data, hot)
    local len = #data
    local data_ptr = ffi.new("uint8_t[?]", len)
    ffi.copy(data_ptr, data, len)
    
    local handle = lib.kestrel_load_expert(
        Router.ctx,
        expert_id,
        data_ptr,
        len,
        hot or false
    )
    
    if handle == nil then
        error("Failed to load expert " .. expert_id)
    end
    
    Router.experts[expert_id] = {
        handle = handle,
        data = data_ptr,
        len = len,
        hot = hot or false,
    }
end

-- Expert scoring (simplified for now)
local function score_expert(expert, hidden_states)
    local score = 0.0
    for i = 1, #hidden_states do
        score = score + hidden_states[i] * 0.1
    end
    return score
end

-- Top-k selection (returns array of expert_ids)
local function select_top_k(scores, expert_ids, k)
    local indices = {}
    local values = {}
    
    for i = 1, #scores do
        indices[i] = i
        values[i] = scores[i]
    end
    
    -- Simple sort (descending)
    for i = 1, #values do
        for j = i + 1, #values do
            if values[j] > values[i] then
                values[i], values[j] = values[j], values[i]
                indices[i], indices[j] = indices[j], indices[i]
            end
        end
    end
    
    local result = {}
    for i = 1, math.min(k, #indices) do
        result[i] = expert_ids[indices[i]]
    end
    
    return result
end

-- Route tokens through experts
function Router.route(hidden_states)
    -- Score all experts
    local scores = {}
    local expert_ids = {}
    local count = 0
    
    for expert_id, expert in pairs(Router.experts) do
        count = count + 1
        expert_ids[count] = expert_id
        scores[count] = score_expert(expert, hidden_states)
    end
    
    -- Select top-k experts
    local selected_experts = select_top_k(scores, expert_ids, Router.top_k)
    
    -- Invoke selected experts
    local output = ffi.new("float[?]", #hidden_states)
    local results = {}
    
    for i = 1, #selected_experts do
        local expert_id = selected_experts[i]
        local input_ptr = ffi.new("float[?]", #hidden_states)
        
        -- Convert Lua table (1-based) to C array (0-based)
        for j = 1, #hidden_states do
            input_ptr[j - 1] = hidden_states[j]
        end
        
        local ret = lib.kestrel_forward(
            Router.ctx,
            expert_id,
            input_ptr,
            #hidden_states,
            output,
            #hidden_states
        )
        
        if ret == 0 then
            local expert_output = {}
            for j = 0, #hidden_states - 1 do
                expert_output[j + 1] = output[j]
            end
            results[expert_id] = expert_output
        end
    end
    
    -- Add metadata
    results._count = #selected_experts
    results._selected = selected_experts
    
    return results
end

-- Get memory usage
function Router.memory_usage()
    if Router.ctx then
        return tonumber(lib.kestrel_get_memory_usage(Router.ctx))
    end
    return 0
end

-- Cleanup
function Router.deinit()
    if Router.ctx then
        -- Unload all experts
        for _, expert in pairs(Router.experts) do
            lib.kestrel_unload_expert(expert.handle)
        end
        Router.experts = {}
        
        lib.kestrel_deinit(Router.ctx)
        Router.ctx = nil
    end
    Router.initialized = false
end

-- JIT compilation hints
jit.opt.start(
    "hotloop=10",
    "hotexit=2"
)

return Router
