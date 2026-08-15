-- gullwing_direct_integration.lua
-- Direct integration with Gullwing Lua modules (no HTTP needed)
local ffi = require("ffi")

-- Load Kestrel
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

-- Try to load Gullwing modules
local function try_load(module_name)
    local ok, result = pcall(require, module_name)
    if ok then
        return result
    end
    return nil
end

-- Load available Gullwing modules
local moabi_engine = try_load("moabi-engine")
local moabi_analyzer = try_load("moabi-analyzer")
local moabi_features = try_load("moabi-features")
local moabi_memory = try_load("moabi-memory")
local moabi_dynamic = try_load("moabi-dynamic")
local moabi_diff = try_load("moabi-diff")

-- Direct Integration Module
local DirectIntegration = {
    kestrel_ctx = nil,
    experts = {},
    gullwing_modules = {},
    initialized = false,
}

-- Initialize with loaded Gullwing modules
function DirectIntegration.init()
    if DirectIntegration.initialized then
        return
    end
    
    -- Store available Gullwing modules
    DirectIntegration.gullwing_modules = {
        engine = moabi_engine,
        analyzer = moabi_analyzer,
        features = moabi_features,
        memory = moabi_memory,
        dynamic = moabi_dynamic,
        diff = moabi_diff,
    }
    
    -- Print available modules
    print("Available Gullwing modules:")
    for name, module in pairs(DirectIntegration.gullwing_modules) do
        if module then
            print(string.format("  ✓ %s loaded", name))
        else
            print(string.format("  ✗ %s not available", name))
        end
    end
    
    -- Initialize Kestrel
    DirectIntegration.kestrel_ctx = kestrel.kestrel_init(25 * 1024 * 1024 * 1024)
    assert(DirectIntegration.kestrel_ctx ~= nil, "Failed to initialize Kestrel")
    
    -- Load experts
    DirectIntegration.load_experts()
    
    DirectIntegration.initialized = true
    print("✓ Direct Gullwing-Kestrel integration initialized")
end

-- Load Kestrel experts matching Gullwing's capabilities
function DirectIntegration.load_experts()
    local expert_configs = {
        {id = 1, name = "Static Analysis", size = 1024 * 1024},
        {id = 2, name = "Feature Extraction", size = 1024 * 1024},
        {id = 3, name = "Memory Analysis", size = 1024 * 1024},
        {id = 4, name = "Dynamic Analysis", size = 1024 * 1024},
        {id = 5, name = "Binary Diffing", size = 1024 * 1024},
        {id = 6, name = "YARA Matching", size = 1024 * 1024},
        {id = 7, name = "Attestation", size = 1024 * 1024},
        {id = 8, name = "Watch Monitoring", size = 1024 * 1024},
    }
    
    for _, config in ipairs(expert_configs) do
        local data = ffi.new("uint8_t[?]", config.size)
        local handle = kestrel.kestrel_load_expert(
            DirectIntegration.kestrel_ctx,
            config.id,
            data,
            config.size,
            config.id <= 4
        )
        
        if handle ~= nil then
            DirectIntegration.experts[config.id] = {
                handle = handle,
                name = config.name,
                hot = config.id <= 4,
            }
            print(string.format("  ✓ Expert %d: %s (%s)", 
                  config.id, config.name, config.id <= 4 and "hot" or "cold"))
        end
    end
end

-- Use Gullwing's actual analysis if available
function DirectIntegration.analyze_binary(binary_path)
    local results = {}
    
    -- Try using Gullwing's modules first
    if DirectIntegration.gullwing_modules.analyzer then
        local ok, gullwing_result = pcall(function()
            return DirectIntegration.gullwing_modules.analyzer.analyze(binary_path)
        end)
        
        if ok and gullwing_result then
            results.gullwing = gullwing_result
        end
    end
    
    -- Extract features if module available
    if DirectIntegration.gullwing_modules.features then
        local ok, features = pcall(function()
            return DirectIntegration.gullwing_modules.features.extract(binary_path)
        end)
        
        if ok and features then
            results.features = features
        end
    end
    
    -- Run Kestrel enhancement
    results.kestrel = DirectIntegration.kestrel_analyze(binary_path)
    
    return results
end

-- Kestrel analysis of binary
function DirectIntegration.kestrel_analyze(binary_path)
    local file = io.open(binary_path, "rb")
    if not file then
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Extract features (first 256 bytes)
    local features = {}
    for i = 1, math.min(#content, 256) do
        features[i] = content:byte(i) / 255.0
    end
    
    -- Run through hot experts only for speed
    local analysis = {}
    for expert_id = 1, 4 do
        local input = ffi.new("float[?]", #features)
        for i = 1, #features do
            input[i - 1] = features[i]
        end
        
        local output = ffi.new("float[?]", 10)
        local ret = kestrel.kestrel_forward(
            DirectIntegration.kestrel_ctx,
            expert_id,
            input,
            #features,
            output,
            10
        )
        
        if ret == 0 then
            local result = {}
            for i = 0, 9 do
                result[i + 1] = output[i]
            end
            analysis[DirectIntegration.experts[expert_id].name] = result
        end
    end
    
    return analysis
end

-- Check if a specific Gullwing module is available
function DirectIntegration.has_module(name)
    return DirectIntegration.gullwing_modules[name] ~= nil
end

-- Get list of available Gullwing functions
function DirectIntegration.list_functions()
    local functions = {}
    
    for name, module in pairs(DirectIntegration.gullwing_modules) do
        if module then
            functions[name] = {}
            for key, value in pairs(module) do
                if type(value) == "function" then
                    table.insert(functions[name], key)
                end
            end
        end
    end
    
    return functions
end

-- Cleanup
function DirectIntegration.deinit()
    if DirectIntegration.kestrel_ctx then
        for _, expert in pairs(DirectIntegration.experts) do
            kestrel.kestrel_unload_expert(expert.handle)
        end
        DirectIntegration.experts = {}
        kestrel.kestrel_deinit(DirectIntegration.kestrel_ctx)
        DirectIntegration.kestrel_ctx = nil
    end
    DirectIntegration.initialized = false
end

return DirectIntegration
