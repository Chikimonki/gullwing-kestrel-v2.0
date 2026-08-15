-- gullwing_engine_integration.lua
-- Integrate Kestrel v2.0 with moabi-engine.lua (Gullwing's LLM engine registry)
local ffi = require("ffi")

-- Add Gullwing source to path
package.path = "/mnt/d/moabi/src/?.lua;" .. package.path

-- Load Kestrel C ABI
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
]]

local kestrel = ffi.load("/mnt/d/moabi/gullwing-kestrel/libkestrel.so")

-- Load Gullwing's engine registry
local ok_engine, moabi_engine = pcall(require, "moabi-engine")
if not ok_engine then
    print("Warning: moabi-engine.lua not found, using standalone mode")
    moabi_engine = {
        _VERSION = "standalone",
        build_prompt = function(evidence)
            return "Binary Analysis Evidence:\n" .. evidence
        end
    }
end

-- Integration Module
local EngineIntegration = {
    kestrel_ctx = nil,
    experts = {},
    engine = moabi_engine,
    initialized = false,
}

-- Initialize Kestrel as Gullwing's Tier 1 engine
function EngineIntegration.init()
    if EngineIntegration.initialized then
        return
    end
    
    print("=== Kestrel v2.0 Engine Integration ===")
    print(string.format("Gullwing Engine Version: %s", moabi_engine._VERSION))
    print()
    
    -- Initialize Kestrel with 25GB
    EngineIntegration.kestrel_ctx = kestrel.kestrel_init(25 * 1024 * 1024 * 1024)
    assert(EngineIntegration.kestrel_ctx ~= nil, "Failed to initialize Kestrel")
    
    -- Load binary analysis experts
    EngineIntegration.load_binary_experts()
    
    EngineIntegration.initialized = true
    print("✓ Kestrel registered as Tier 1 engine")
end

-- Load experts specialized for binary analysis
function EngineIntegration.load_binary_experts()
    local expert_types = {
        {id = 1, name = "ELF Analysis", desc = "ELF header, sections, symbols"},
        {id = 2, name = "PE Analysis", desc = "PE structure, imports, exports"},
        {id = 3, name = "Entropy", desc = "Global and windowed entropy"},
        {id = 4, name = "ML Classification", desc = "Weighted k-NN classifier"},
        {id = 5, name = "Runtime", desc = "Syscall and behavior analysis"},
        {id = 6, name = "Memory", desc = "Page mappings and inspection"},
        {id = 7, name = "Memory Diff", desc = "Disk vs memory comparison"},
        {id = 8, name = "SBOM", desc = "Software bill of materials"},
    }
    
    for _, expert in ipairs(expert_types) do
        local data = ffi.new("uint8_t[?]", 1024 * 1024)  -- 1MB weights
        local handle = kestrel.kestrel_load_expert(
            EngineIntegration.kestrel_ctx,
            expert.id,
            data,
            1024 * 1024,
            expert.id <= 4  -- Hot experts
        )
        
        if handle ~= nil then
            EngineIntegration.experts[expert.id] = {
                handle = handle,
                name = expert.name,
                description = expert.desc,
                hot = expert.id <= 4,
            }
            print(string.format("  ✓ Expert %d: %s (%s)", 
                  expert.id, expert.name, expert.id <= 4 and "hot" or "cold"))
        end
    end
end

-- Build evidence-based prompt like moabi-engine does
function EngineIntegration.build_binary_prompt(binary_path)
    -- Read and analyze binary
    local analysis = EngineIntegration.analyze_binary(binary_path)
    
    if not analysis then
        return nil
    end
    
    -- Format as evidence for LLM
    local evidence_lines = {}
    for expert_id, result in pairs(analysis) do
        local expert = EngineIntegration.experts[expert_id]
        if expert then
            table.insert(evidence_lines, string.format(
                "[%s] %s: confidence=%.2f", 
                expert.name, expert.description, result.confidence or 0.5
            ))
        end
    end
    
    local evidence = table.concat(evidence_lines, "\n")
    
    -- Use moabi-engine's prompt builder
    if EngineIntegration.engine.build_prompt then
        return EngineIntegration.engine.build_prompt(evidence)
    end
    
    return evidence
end

-- Analyze binary with Kestrel experts
function EngineIntegration.analyze_binary(binary_path)
    local file = io.open(binary_path, "rb")
    if not file then
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Extract features
    local features = {}
    for i = 1, math.min(#content, 512) do
        features[i] = content:byte(i) / 255.0
    end
    
    -- Run through experts
    local results = {}
    for expert_id, expert in pairs(EngineIntegration.experts) do
        local input = ffi.new("float[?]", #features)
        for i = 1, #features do
            input[i - 1] = features[i]
        end
        
        local output = ffi.new("float[?]", 10)
        local ret = kestrel.kestrel_forward(
            EngineIntegration.kestrel_ctx,
            expert_id,
            input,
            #features,
            output,
            10
        )
        
        if ret == 0 then
            -- Compute simple confidence from outputs
            local sum = 0.0
            for i = 0, 9 do
                sum = sum + output[i]
            end
            local confidence = sum / 10.0
            
            results[expert_id] = {
                confidence = confidence,
                outputs = {},
            }
            for i = 0, 9 do
                results[expert_id].outputs[i + 1] = output[i]
            end
        end
    end
    
    return results
end

-- Get engine configuration
function EngineIntegration.get_config()
    return {
        engine = "kestrel-ffi",
        version = "2.0",
        memory_budget = tonumber(kestrel.kestrel_get_memory_usage(EngineIntegration.kestrel_ctx)),
        experts_loaded = #EngineIntegration.experts,
        hot_experts = EngineIntegration.count_hot_experts(),
    }
end

-- Count hot experts
function EngineIntegration.count_hot_experts()
    local count = 0
    for _, expert in pairs(EngineIntegration.experts) do
        if expert.hot then
            count = count + 1
        end
    end
    return count
end

-- Cleanup
function EngineIntegration.deinit()
    if EngineIntegration.kestrel_ctx then
        for _, expert in pairs(EngineIntegration.experts) do
            kestrel.kestrel_unload_expert(expert.handle)
        end
        EngineIntegration.experts = {}
        kestrel.kestrel_deinit(EngineIntegration.kestrel_ctx)
        EngineIntegration.kestrel_ctx = nil
    end
    EngineIntegration.initialized = false
end

return EngineIntegration
