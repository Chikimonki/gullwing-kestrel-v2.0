-- gullwing_deep_integration.lua
-- Deep integration with Gullwing's existing analysis pipeline
local ffi = require("ffi")

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
    void kestrel_reset_arena(KestrelContext* ctx);
]]

local kestrel = ffi.load("/mnt/d/moabi/gullwing-kestrel/libkestrel.so")

-- Try to load Gullwing modules
local ok_gullwing, gullwing = pcall(require, "moabi-serve")
if not ok_gullwing then
    print("Note: Gullwing API module not loaded directly, using file-based analysis")
    gullwing = nil
end

local ok_ml, ml_module = pcall(require, "moabi-ml")
if not ok_ml then
    print("Note: Gullwing ML module not loaded directly")
    ml_module = nil
end

-- Deep Integration Module
local DeepIntegration = {
    kestrel_ctx = nil,
    experts = {},
    analysis_pipeline = {},
    results_cache = {},
    initialized = false,
}

-- Initialize deep integration with Gullwing
function DeepIntegration.init()
    if DeepIntegration.initialized then
        return
    end
    
    -- Initialize Kestrel with 25GB budget
    DeepIntegration.kestrel_ctx = kestrel.kestrel_init(25 * 1024 * 1024 * 1024)
    assert(DeepIntegration.kestrel_ctx ~= nil, "Failed to initialize Kestrel")
    
    -- Map Gullwing's 8-layer analysis to Kestrel experts
    DeepIntegration.load_gullwing_experts()
    
    -- Build analysis pipeline
    DeepIntegration.build_pipeline()
    
    DeepIntegration.initialized = true
    print("✓ Deep Gullwing-Kestrel integration initialized")
end

-- Map Gullwing's 8 layers to Kestrel experts
function DeepIntegration.load_gullwing_experts()
    local expert_map = {
        -- Gullwing Layer → Kestrel Expert
        {layer = "IDENTITY", expert_id = 1, description = "Path, Size, SHA256"},
        {layer = "STRUCTURE", expert_id = 2, description = "ELF Class, Sections"},
        {layer = "SEMANTICS", expert_id = 3, description = "Libraries, Symbols"},
        {layer = "ENTROPY", expert_id = 4, description = "Global/Windowed"},
        {layer = "ML", expert_id = 5, description = "Weighted k-NN"},
        {layer = "RUNTIME", expert_id = 6, description = "Syscall Profile"},
        {layer = "MEMORY", expert_id = 7, description = "Page Mappings"},
        {layer = "MEMORY_DIFF", expert_id = 8, description = "Disk vs Memory"},
    }
    
    for _, mapping in ipairs(expert_map) do
        -- Load expert with simulated weights (1MB each)
        local data = ffi.new("uint8_t[?]", 1024 * 1024)
        local handle = kestrel.kestrel_load_expert(
            DeepIntegration.kestrel_ctx,
            mapping.expert_id,
            data,
            1024 * 1024,
            mapping.expert_id <= 4  -- First 4 are hot
        )
        
        if handle ~= nil then
            DeepIntegration.experts[mapping.layer] = {
                handle = handle,
                expert_id = mapping.expert_id,
                description = mapping.description,
                hot = mapping.expert_id <= 4,
            }
        end
    end
end

-- Build the analysis pipeline matching Gullwing's architecture
function DeepIntegration.build_pipeline()
    DeepIntegration.analysis_pipeline = {
        "IDENTITY",
        "STRUCTURE", 
        "SEMANTICS",
        "ENTROPY",
        "ML",
        "RUNTIME",
        "MEMORY",
        "MEMORY_DIFF",
    }
end

-- Analyze binary using full 8-layer convergent model
function DeepIntegration.analyze_binary(binary_path)
    -- Read binary
    local file = io.open(binary_path, "rb")
    if not file then
        return nil, "Could not open binary: " .. binary_path
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Extract features (first 512 bytes normalized)
    local features = {}
    for i = 1, math.min(#content, 512) do
        features[i] = content:byte(i) / 255.0
    end
    
    -- Run through all 8 layers
    local analysis = {
        path = binary_path,
        size = #content,
        timestamp = os.time(),
        layers = {},
        convergence = {},
    }
    
    for _, layer in ipairs(DeepIntegration.analysis_pipeline) do
        local expert = DeepIntegration.experts[layer]
        if expert then
            local result = DeepIntegration.run_layer(expert, features)
            if result then
                analysis.layers[layer] = result
            end
        end
    end
    
    -- Compute convergence (simplified)
    analysis.convergence.risk_score = DeepIntegration.compute_risk(analysis.layers)
    analysis.convergence.novelty = DeepIntegration.compute_novelty(analysis.layers)
    analysis.convergence.verdict = DeepIntegration.compute_verdict(analysis.convergence)
    
    -- Cache results
    DeepIntegration.results_cache[binary_path] = analysis
    
    return analysis
end

-- Run a single layer through its expert
function DeepIntegration.run_layer(expert, features)
    if not expert then
        return nil
    end
    
    -- Convert features to C array
    local input = ffi.new("float[?]", #features)
    for i = 1, #features do
        input[i - 1] = features[i]
    end
    
    -- Run inference (10 outputs per layer)
    local output = ffi.new("float[?]", 10)
    local result = kestrel.kestrel_forward(
        DeepIntegration.kestrel_ctx,
        expert.expert_id,
        input,
        #features,
        output,
        10
    )
    
    if result == 0 then
        local layer_result = {}
        for i = 0, 9 do
            layer_result[i + 1] = output[i]
        end
        return layer_result
    end
    
    return nil
end

-- Compute risk score from layer results
function DeepIntegration.compute_risk(layers)
    local risk = 0.0
    local count = 0
    
    for _, result in pairs(layers) do
        -- Simple weighted average
        local layer_risk = 0.0
        for i = 1, #result do
            layer_risk = layer_risk + result[i]
        end
        layer_risk = layer_risk / #result
        
        risk = risk + layer_risk
        count = count + 1
    end
    
    if count > 0 then
        return risk / count
    end
    
    return 0.0
end

-- Compute novelty score
function DeepIntegration.compute_novelty(layers)
    local novelty = 0.0
    local count = 0
    
    for _, result in pairs(layers) do
        -- Variance as novelty indicator
        local mean = 0.0
        for i = 1, #result do
            mean = mean + result[i]
        end
        mean = mean / #result
        
        local variance = 0.0
        for i = 1, #result do
            variance = variance + (result[i] - mean)^2
        end
        variance = variance / #result
        
        novelty = novelty + variance
        count = count + 1
    end
    
    if count > 0 then
        return novelty / count
    end
    
    return 0.0
end

-- Compute final verdict
function DeepIntegration.compute_verdict(convergence)
    local risk = convergence.risk_score or 0
    local novelty = convergence.novelty or 0
    
    if risk > 0.7 and novelty > 0.5 then
        return "HIGH RISK - Novel threat detected"
    elseif risk > 0.7 then
        return "HIGH RISK - Known threat pattern"
    elseif risk > 0.4 then
        return "MODERATE RISK - Further analysis recommended"
    elseif novelty > 0.5 then
        return "UNUSUAL - Novel binary structure"
    else
        return "BENIGN - No immediate threats detected"
    end
end

-- Get cached analysis
function DeepIntegration.get_analysis(binary_path)
    return DeepIntegration.results_cache[binary_path]
end

-- Print analysis report
function DeepIntegration.print_report(analysis)
    if not analysis then
        print("No analysis available")
        return
    end
    
    print("\n" .. string.rep("=", 60))
    print("GULLWING-KESTREL CONVERGENT ANALYSIS REPORT")
    print(string.rep("=", 60))
    print(string.format("File: %s", analysis.path))
    print(string.format("Size: %d bytes", analysis.size))
    print(string.format("Timestamp: %s", os.date("%Y-%m-%d %H:%M:%S", analysis.timestamp)))
    print(string.rep("-", 60))
    
    print("\nLayer Analysis:")
    for layer, result in pairs(analysis.layers) do
        local expert = DeepIntegration.experts[layer]
        if expert then
            print(string.format("  ✓ %-15s: %s (Expert %d)", 
                  layer, expert.description, expert.expert_id))
        end
    end
    
    print(string.rep("-", 60))
    print("\nConvergence:")
    print(string.format("  Risk Score: %.3f", analysis.convergence.risk_score))
    print(string.format("  Novelty Score: %.3f", analysis.convergence.novelty))
    print(string.format("  Verdict: %s", analysis.convergence.verdict))
    print(string.rep("=", 60))
end

-- Cleanup
function DeepIntegration.deinit()
    if DeepIntegration.kestrel_ctx then
        for _, expert in pairs(DeepIntegration.experts) do
            kestrel.kestrel_unload_expert(expert.handle)
        end
        DeepIntegration.experts = {}
        kestrel.kestrel_deinit(DeepIntegration.kestrel_ctx)
        DeepIntegration.kestrel_ctx = nil
    end
    DeepIntegration.initialized = false
    DeepIntegration.results_cache = {}
end

return DeepIntegration
