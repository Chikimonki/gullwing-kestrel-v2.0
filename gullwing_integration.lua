-- gullwing_integration.lua
-- Real integration between Kestrel v2.0 and Gullwing binary analysis
local ffi = require("ffi")

-- Load both libraries
ffi.cdef[[
    // Kestrel types
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
    
    // Kestrel functions
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
    size_t kestrel_get_memory_usage(KestrelContext* ctx);
    void kestrel_reset_arena(KestrelContext* ctx);
]]

local kestrel = ffi.load("/mnt/d/moabi/gullwing-kestrel/libkestrel.so")

-- Gullwing Integration Module
local GullwingKestrel = {
    ctx = nil,
    experts = {},
    analysis_cache = {},
}

-- Initialize Kestrel for Gullwing binary analysis
function GullwingKestrel.init()
    if GullwingKestrel.ctx then
        return
    end
    
    -- 25GB memory budget for full binary analysis
    GullwingKestrel.ctx = kestrel.kestrel_init(25 * 1024 * 1024 * 1024)
    assert(GullwingKestrel.ctx ~= nil, "Failed to initialize Kestrel")
    
    -- Load binary analysis experts
    GullwingKestrel.load_analysis_experts()
    
    print("✓ Gullwing-Kestrel integration initialized")
    print(string.format("  Memory budget: %.1f GB", 
          tonumber(GullwingKestrel.ctx.total_memory) / 1024 / 1024 / 1024))
end

-- Load experts for different binary analysis tasks
function GullwingKestrel.load_analysis_experts()
    local experts = {
        {id = 1, name = "ELF Header Analysis", hot = true},
        {id = 2, name = "PE Structure Analysis", hot = true},
        {id = 3, name = "Entropy Detection", hot = true},
        {id = 4, name = "Malware Pattern Matching", hot = false},
        {id = 5, name = "Supply Chain Verification", hot = false},
        {id = 6, name = "Memory Differential Analysis", hot = false},
        {id = 7, name = "ML Classification", hot = true},
        {id = 8, name = "Runtime Behavior Analysis", hot = false},
    }
    
    for _, expert in ipairs(experts) do
        -- Load expert weights (simplified for now)
        local data = ffi.new("uint8_t[?]", 1024 * 1024)  -- 1MB each
        local handle = kestrel.kestrel_load_expert(
            GullwingKestrel.ctx,
            expert.id,
            data,
            1024 * 1024,
            expert.hot
        )
        
        if handle ~= nil then
            GullwingKestrel.experts[expert.id] = {
                handle = handle,
                name = expert.name,
                hot = expert.hot,
            }
            print(string.format("  ✓ %s (Expert %d, %s)", 
                  expert.name, expert.id, expert.hot and "hot" or "cold"))
        end
    end
end

-- Analyze binary using Kestrel experts
function GullwingKestrel.analyze_binary(binary_path)
    -- Read binary file
    local file = io.open(binary_path, "rb")
    if not file then
        error("Could not open binary: " .. binary_path)
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Convert binary content to feature vector
    local features = GullwingKestrel.extract_features(content)
    
    -- Route through relevant experts
    local results = {}
    
    -- ELF Header Analysis (Expert 1)
    if GullwingKestrel.experts[1] then
        results.elf_header = GullwingKestrel.run_expert(1, features)
    end
    
    -- Entropy Detection (Expert 3)
    if GullwingKestrel.experts[3] then
        results.entropy = GullwingKestrel.run_expert(3, features)
    end
    
    -- ML Classification (Expert 7)
    if GullwingKestrel.experts[7] then
        results.ml_classification = GullwingKestrel.run_expert(7, features)
    end
    
    -- Cache results
    GullwingKestrel.analysis_cache[binary_path] = {
        results = results,
        timestamp = os.time(),
        binary_size = #content,
    }
    
    return results
end

-- Extract features from binary content
function GullwingKestrel.extract_features(content)
    local features = {}
    
    -- Basic features (first 512 bytes as float values)
    local num_features = math.min(#content, 512)
    for i = 1, num_features do
        features[i] = content:byte(i) / 255.0
    end
    
    return features
end

-- Run a specific expert on features
function GullwingKestrel.run_expert(expert_id, features)
    local expert = GullwingKestrel.experts[expert_id]
    if not expert then
        return nil
    end
    
    -- Convert features to C array
    local input = ffi.new("float[?]", #features)
    for i = 1, #features do
        input[i - 1] = features[i]
    end
    
    -- Run inference
    local output = ffi.new("float[?]", 10)  -- 10 output values
    local result = kestrel.kestrel_forward(
        GullwingKestrel.ctx,
        expert_id,
        input,
        #features,
        output,
        10
    )
    
    if result == 0 then
        -- Convert output to Lua table
        local analysis = {}
        for i = 0, 9 do
            analysis[i + 1] = output[i]
        end
        return analysis
    end
    
    return nil
end

-- Get analysis summary
function GullwingKestrel.get_summary(binary_path)
    local cached = GullwingKestrel.analysis_cache[binary_path]
    if not cached then
        return nil
    end
    
    local summary = {
        path = binary_path,
        size = cached.binary_size,
        timestamp = cached.timestamp,
        experts_used = 0,
        total_memory_mb = tonumber(kestrel.kestrel_get_memory_usage(GullwingKestrel.ctx)) / 1024 / 1024,
    }
    
    for _, result in pairs(cached.results) do
        summary.experts_used = summary.experts_used + 1
    end
    
    return summary
end

-- Cleanup
function GullwingKestrel.deinit()
    if GullwingKestrel.ctx then
        for _, expert in pairs(GullwingKestrel.experts) do
            kestrel.kestrel_unload_expert(expert.handle)
        end
        GullwingKestrel.experts = {}
        kestrel.kestrel_deinit(GullwingKestrel.ctx)
        GullwingKestrel.ctx = nil
    end
end

return GullwingKestrel
