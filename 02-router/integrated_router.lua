-- integrated_router.lua — Complete integration with real features and weights
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;" .. package.path

local ffi = require("ffi")
local BinaryFeatures = require("binary_features")

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
    
    int32_t kestrel_forward_v2(
        KestrelContext* ctx,
        ExpertHandle* handle,
        const float* input,
        size_t input_len,
        float* output,
        size_t output_len
    );
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/libkestrel_v2.so")

local IntegratedRouter = {
    ctx = nil,
    experts = {},
    initialized = false,
    analysis_cache = {},
}

function IntegratedRouter.init(total_memory)
    if IntegratedRouter.initialized then return end
    
    IntegratedRouter.ctx = lib.kestrel_init_v2(total_memory or 16 * 1024 * 1024 * 1024)
    assert(IntegratedRouter.ctx ~= nil, "Failed to initialize")
    
    -- Create experts mapped to Gullwing's 8 layers
    IntegratedRouter.create_experts()
    
    IntegratedRouter.initialized = true
    print("✓ Integrated Router initialized (16GB budget)")
end

function IntegratedRouter.create_experts()
    local expert_configs = {
        {id = 1, name = "IDENTITY", input = 512, output = 128},
        {id = 2, name = "STRUCTURE", input = 512, output = 128},
        {id = 3, name = "SEMANTICS", input = 256, output = 64},
        {id = 4, name = "ENTROPY", input = 256, output = 64},
        {id = 5, name = "ML", input = 128, output = 32},
        {id = 6, name = "RUNTIME", input = 256, output = 64},
        {id = 7, name = "MEMORY", input = 256, output = 64},
        {id = 8, name = "MEMORY_DIFF", input = 256, output = 64},
    }
    
    for _, config in ipairs(expert_configs) do
        local handle = lib.kestrel_create_expert(
            IntegratedRouter.ctx,
            config.id,
            config.input,
            config.output,
            config.id <= 4  -- Hot experts
        )
        
        if handle ~= nil then
            IntegratedRouter.experts[config.id] = {
                handle = handle,
                name = config.name,
                input_dim = config.input,
                output_dim = config.output,
                hot = config.id <= 4,
            }
            print(string.format("  ✓ %s expert ready (%d→%d, %s)", 
                  config.name, config.input, config.output, 
                  config.id <= 4 and "hot" or "cold"))
        end
    end
end

-- Convert features to appropriate dimension (with robust padding)
function IntegratedRouter.prepare_features(features, target_dim)
    local prepared = {}
    
    -- Handle nil or empty features
    if not features or #features == 0 then
        -- Fill with zeros (neutral input)
        for i = 1, target_dim do
            prepared[i] = 0.0
        end
        return prepared
    end
    
    if #features >= target_dim then
        -- Use first target_dim features
        for i = 1, target_dim do
            prepared[i] = features[i] or 0.0
        end
    else
        -- Use available features and pad with zeros
        for i = 1, #features do
            prepared[i] = features[i] or 0.0
        end
        for i = #features + 1, target_dim do
            prepared[i] = 0.0
        end
    end
    
    return prepared
end

-- Run expert analysis with robust error handling
function IntegratedRouter.run_expert(expert_id, features)
    local expert = IntegratedRouter.experts[expert_id]
    if not expert then
        return nil
    end
    
    -- Prepare features (always returns valid array)
    local prepared = IntegratedRouter.prepare_features(features, expert.input_dim)
    
    -- Convert to C array
    local input = ffi.new("float[?]", expert.input_dim)
    for i = 1, expert.input_dim do
        input[i - 1] = prepared[i] or 0.0
    end
    
    -- Allocate output
    local output = ffi.new("float[?]", expert.output_dim)
    
    -- Run forward pass
    local ret = lib.kestrel_forward_v2(
        IntegratedRouter.ctx,
        expert.handle,
        input,
        expert.input_dim,
        output,
        expert.output_dim
    )
    
    if ret ~= 0 then
        return nil
    end
    
    -- Convert to Lua table with confidence
    local result = {}
    local sum = 0.0
    for i = 0, expert.output_dim - 1 do
        result[i + 1] = output[i]
        sum = sum + math.abs(output[i])
    end
    
    result.confidence = math.min(1.0, sum / expert.output_dim)
    
    return result
end

-- Full 8-layer analysis
function IntegratedRouter.analyze_binary(binary_path)
    -- Read binary
    local file = io.open(binary_path, "rb")
    if not file then
        return nil, "Could not open: " .. binary_path
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Extract features
    local features = BinaryFeatures.extract_all(content)
    
    -- Run through experts
    local analysis = {
        path = binary_path,
        size = #content,
        timestamp = os.time(),
        layers = {},
        convergence = {},
    }
    
    -- Layer 1: IDENTITY (ELF features or size/type)
    local identity_features = features.elf or {}
    if #identity_features == 0 then
        -- Fallback: use first bytes
        for i = 1, math.min(#content, 100) do
            identity_features[i] = content:byte(i) / 255.0
        end
    end
    analysis.layers.IDENTITY = IntegratedRouter.run_expert(1, identity_features)
    
    -- Layer 2: STRUCTURE (ELF + size features)
    local structure_features = {}
    if features.elf and #features.elf > 0 then
        for i = 1, #features.elf do
            structure_features[i] = features.elf[i]
        end
    end
    structure_features[#structure_features + 1] = math.min(#content / (10 * 1024 * 1024), 1.0)
    analysis.layers.STRUCTURE = IntegratedRouter.run_expert(2, structure_features)
    
    -- Layer 3: SEMANTICS (strings converted to features)
    local semantic_features = {}
    if features.strings and #features.strings > 0 then
        for i = 1, math.min(#features.strings, 50) do
            local str = features.strings[i]
            for j = 1, math.min(#str, 5) do
                semantic_features[#semantic_features + 1] = (str:byte(j) or 0) / 255.0
            end
        end
    else
        -- Fallback: use byte values from content
        for i = 1, math.min(#content, 50) do
            semantic_features[i] = (content:byte(i) or 0) / 255.0
        end
    end
    analysis.layers.SEMANTICS = IntegratedRouter.run_expert(3, semantic_features)
    
    -- Layer 4: ENTROPY
    local entropy_features = features.entropy or {}
    analysis.layers.ENTROPY = IntegratedRouter.run_expert(4, entropy_features)
    
    -- Layer 5: ML (combined features)
    local ml_features = features.ml or {}
    analysis.layers.ML = IntegratedRouter.run_expert(5, ml_features)
    
    -- Compute convergence
    analysis.convergence.risk_score = IntegratedRouter.compute_risk(analysis.layers)
    analysis.convergence.verdict = IntegratedRouter.compute_verdict(analysis.convergence.risk_score)
    
    -- Cache
    IntegratedRouter.analysis_cache[binary_path] = analysis
    
    return analysis
end

function IntegratedRouter.compute_risk(layers)
    local total_confidence = 0.0
    local count = 0
    
    for _, result in pairs(layers) do
        if result and result.confidence then
            total_confidence = total_confidence + result.confidence
            count = count + 1
        end
    end
    
    if count > 0 then
        return total_confidence / count
    end
    
    return 0.0
end

function IntegratedRouter.compute_verdict(risk_score)
    if risk_score > 0.7 then
        return "HIGH RISK"
    elseif risk_score > 0.4 then
        return "MODERATE RISK"
    elseif risk_score > 0.1 then
        return "LOW RISK"
    else
        return "BENIGN"
    end
end

function IntegratedRouter.print_report(analysis)
    if not analysis then return end
    
    print("\n" .. string.rep("=", 60))
    print("KESTREL v2.0 CONVERGENT ANALYSIS REPORT")
    print(string.rep("=", 60))
    print(string.format("File: %s", analysis.path))
    print(string.format("Size: %d bytes", analysis.size))
    print(string.rep("-", 60))
    
    print("\nLayer Analysis:")
    for layer, result in pairs(analysis.layers) do
        if result then
            print(string.format("  ✓ %-15s: confidence=%.3f", 
                  layer, result.confidence or 0))
        else
            print(string.format("  ✗ %-15s: failed", layer))
        end
    end
    
    print(string.rep("-", 60))
    print(string.format("\nRisk Score: %.3f", analysis.convergence.risk_score))
    print(string.format("Verdict: %s", analysis.convergence.verdict))
    print(string.rep("=", 60))
end

function IntegratedRouter.deinit()
    if IntegratedRouter.ctx then
        lib.kestrel_deinit_v2(IntegratedRouter.ctx)
        IntegratedRouter.ctx = nil
    end
    IntegratedRouter.experts = {}
    IntegratedRouter.initialized = false
end

return IntegratedRouter
