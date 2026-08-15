-- gullwing_api_integration.lua
-- Connect Kestrel to Gullwing's actual HTTP API
local ffi = require("ffi")
local socket = require("socket")

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

-- Gullwing API Integration
local GullwingAPI = {
    kestrel_ctx = nil,
    experts = {},
    gullwing_url = "http://127.0.0.1:9393",
    initialized = false,
}

-- Check if Gullwing API is running
function GullwingAPI.check_gullwing()
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    
    local response_body = {}
    local res, code = http.request{
        url = GullwingAPI.gullwing_url .. "/health",
        sink = ltn12.sink.table(response_body),
        create = function()
            local sock = socket.tcp()
            sock:settimeout(2)
            return sock
        end
    }
    
    if code == 200 then
        return true, table.concat(response_body)
    end
    
    return false, "Gullwing API not responding (code: " .. tostring(code) .. ")"
end

-- Initialize Kestrel with Gullwing
function GullwingAPI.init()
    if GullwingAPI.initialized then
        return
    end
    
    -- Check if Gullwing is running
    local gullwing_running, message = GullwingAPI.check_gullwing()
    if not gullwing_running then
        print("⚠ " .. message)
        print("  Starting Gullwing API...")
        os.execute("cd /mnt/d/moabi && luajit src/moabi-serve.lua &")
        os.execute("sleep 2")  -- Wait for API to start
        
        -- Check again
        gullwing_running, message = GullwingAPI.check_gullwing()
        if not gullwing_running then
            print("  Could not start Gullwing API")
            return false
        end
    end
    
    print("✓ Connected to Gullwing API at " .. GullwingAPI.gullwing_url)
    
    -- Initialize Kestrel
    GullwingAPI.kestrel_ctx = kestrel.kestrel_init(25 * 1024 * 1024 * 1024)
    assert(GullwingAPI.kestrel_ctx ~= nil, "Failed to initialize Kestrel")
    
    -- Load analysis experts
    GullwingAPI.load_experts()
    
    GullwingAPI.initialized = true
    return true
end

-- Load Kestrel experts for Gullwing analysis
function GullwingAPI.load_experts()
    local experts_config = {
        {id = 1, name = "identity", size = 1024 * 1024},
        {id = 2, name = "structure", size = 1024 * 1024},
        {id = 3, name = "semantics", size = 1024 * 1024},
        {id = 4, name = "entropy", size = 1024 * 1024},
        {id = 5, name = "ml", size = 1024 * 1024},
        {id = 6, name = "runtime", size = 1024 * 1024},
        {id = 7, name = "memory", size = 1024 * 1024},
        {id = 8, name = "memory_diff", size = 1024 * 1024},
    }
    
    for _, config in ipairs(experts_config) do
        local data = ffi.new("uint8_t[?]", config.size)
        local handle = kestrel.kestrel_load_expert(
            GullwingAPI.kestrel_ctx,
            config.id,
            data,
            config.size,
            config.id <= 4  -- Hot experts
        )
        
        if handle ~= nil then
            GullwingAPI.experts[config.id] = {
                handle = handle,
                name = config.name,
                hot = config.id <= 4,
            }
        end
    end
    
    print(string.format("✓ Loaded %d Kestrel experts", #GullwingAPI.experts))
end

-- Make HTTP request to Gullwing API
function GullwingAPI.http_request(method, path, body)
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local json = require("json")  -- May need to install lua-json
    
    local response_body = {}
    local request_body = body and json.encode(body) or nil
    
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = request_body and #request_body or 0,
    }
    
    local res, code = http.request{
        url = GullwingAPI.gullwing_url .. path,
        method = method,
        headers = headers,
        source = request_body and ltn12.source.string(request_body) or nil,
        sink = ltn12.sink.table(response_body),
        create = function()
            local sock = socket.tcp()
            sock:settimeout(5)
            return sock
        end
    }
    
    if code == 200 then
        local response_text = table.concat(response_body)
        local ok, decoded = pcall(json.decode, response_text)
        if ok then
            return decoded
        end
        return response_text
    end
    
    return nil, "HTTP " .. tostring(code)
end

-- Analyze binary using Gullwing API + Kestrel
function GullwingAPI.analyze_binary(binary_path)
    -- First, check if Gullwing has already analyzed it
    local gullwing_result, err = GullwingAPI.http_request("GET", "/analyze?path=" .. binary_path)
    
    if not gullwing_result then
        -- Fallback: local analysis
        print("  Local analysis fallback for: " .. binary_path)
        return GullwingAPI.local_analysis(binary_path)
    end
    
    -- Enhance with Kestrel analysis
    local kestrel_enhancement = GullwingAPI.kestrel_enhance(gullwing_result)
    
    return {
        gullwing = gullwing_result,
        kestrel = kestrel_enhancement,
        combined = true,
    }
end

-- Local analysis using Kestrel directly
function GullwingAPI.local_analysis(binary_path)
    local file = io.open(binary_path, "rb")
    if not file then
        return nil, "Could not open: " .. binary_path
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
    for expert_id, expert in pairs(GullwingAPI.experts) do
        local input = ffi.new("float[?]", #features)
        for i = 1, #features do
            input[i - 1] = features[i]
        end
        
        local output = ffi.new("float[?]", 10)
        local ret = kestrel.kestrel_forward(
            GullwingAPI.kestrel_ctx,
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
            results[expert.name] = result
        end
    end
    
    return {
        path = binary_path,
        size = #content,
        kestrel_analysis = results,
    }
end

-- Enhance Gullwing results with Kestrel
function GullwingAPI.kestrel_enhance(gullwing_result)
    -- Extract features from Gullwing result
    local features = {}
    
    -- Convert Gullwing output to feature vector
    if type(gullwing_result) == "table" then
        for i = 1, 512 do
            features[i] = math.random() * 0.1  -- Placeholder
        end
    end
    
    -- Run through hot experts only (for speed)
    local enhancement = {}
    for expert_id = 1, 4 do
        local input = ffi.new("float[?]", #features)
        for i = 1, #features do
            input[i - 1] = features[i]
        end
        
        local output = ffi.new("float[?]", 10)
        local ret = kestrel.kestrel_forward(
            GullwingAPI.kestrel_ctx,
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
            enhancement[GullwingAPI.experts[expert_id].name] = result
        end
    end
    
    return enhancement
end

-- Cleanup
function GullwingAPI.deinit()
    if GullwingAPI.kestrel_ctx then
        for _, expert in pairs(GullwingAPI.experts) do
            kestrel.kestrel_unload_expert(expert.handle)
        end
        GullwingAPI.experts = {}
        kestrel.kestrel_deinit(GullwingAPI.kestrel_ctx)
        GullwingAPI.kestrel_ctx = nil
    end
    GullwingAPI.initialized = false
end

return GullwingAPI
