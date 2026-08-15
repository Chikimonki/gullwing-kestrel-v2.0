-- recognition_cache.lua — "Cloak of Invisibility" for known binaries
-- Known binaries skip re-analysis; only new ones get the full 8-layer treatment

local ffi = require("ffi")

ffi.cdef[[
    void* kestrel_accel_create(void);
    int32_t kestrel_accel_load(const char* path);
    double kestrel_accel_benchmark_read(size_t bytes);
    uint64_t kestrel_accel_get_checksum(void);
    void kestrel_accel_destroy(void);
]]

local lib = ffi.load("/mnt/d/moabi/gullwing-kestrel/accelerator/libkestrel_accel.so")

-- The Recognition Cache
local RecognitionCache = {
    known_binaries = {},      -- hash -> cached result
    stats = {
        total_requests = 0,
        cloaked = 0,           -- matched cache
        analysed = 0,          -- full analysis performed
        cache_hits = 0,
    },
    max_cache_size = 1000,    -- Keep last 1000 results
    cache_order = {},          -- LRU order
}

-- Simple fast hash (LuaJIT will JIT-compile this)
local function fast_hash(data)
    local h = 5381
    for i = 1, #data do
        h = (h * 33 + data:byte(i)) % 2^32
    end
    return h
end

-- Check if binary is known (cloaked)
function RecognitionCache.check(binary_path)
    RecognitionCache.stats.total_requests = RecognitionCache.stats.total_requests + 1
    
    -- Quick file existence check
    local file = io.open(binary_path, "rb")
    if not file then
        return nil, "File not found"
    end
    
    -- Read first 4KB for fingerprint (fast)
    local fingerprint = file:read(4096)
    file:close()
    
    -- Compute hash
    local hash = fast_hash(fingerprint)
    
    -- Check cache
    if RecognitionCache.known_binaries[hash] then
        RecognitionCache.stats.cloaked = RecognitionCache.stats.cloaked + 1
        RecognitionCache.stats.cache_hits = RecognitionCache.stats.cache_hits + 1
        
        -- Update LRU
        for i, h in ipairs(RecognitionCache.cache_order) do
            if h == hash then
                table.remove(RecognitionCache.cache_order, i)
                break
            end
        end
        table.insert(RecognitionCache.cache_order, hash)
        
        return RecognitionCache.known_binaries[hash], "cloaked"
    end
    
    -- Not known - needs full analysis
    RecognitionCache.stats.analysed = RecognitionCache.stats.analysed + 1
    
    return nil, "new", hash, fingerprint
end

-- Store result after full analysis
function RecognitionCache.store(hash, result)
    RecognitionCache.known_binaries[hash] = result
    
    -- LRU eviction
    table.insert(RecognitionCache.cache_order, hash)
    
    if #RecognitionCache.cache_order > RecognitionCache.max_cache_size then
        local oldest = table.remove(RecognitionCache.cache_order, 1)
        RecognitionCache.known_binaries[oldest] = nil
    end
end

-- Get stats
function RecognitionCache.get_stats()
    local total = RecognitionCache.stats.total_requests
    local cloak_rate = total > 0 and (RecognitionCache.stats.cloaked / total * 100) or 0
    
    return {
        total_requests = total,
        cloaked = RecognitionCache.stats.cloaked,
        analysed = RecognitionCache.stats.analysed,
        cloak_rate_percent = cloak_rate,
        cache_size = #RecognitionCache.cache_order,
    }
end

-- Simulate full analysis (what we're avoiding for known binaries)
function RecognitionCache.full_analysis(binary_path, hash)
    -- This is where the 8-layer Kestrel analysis would run
    -- For now, we simulate the work
    
    local start = os.clock()
    
    -- Simulate work (in reality: 8 experts, matrix ops, LLM interpretation)
    local result = {
        path = binary_path,
        risk_score = math.random() * 0.1,
        verdict = "BENIGN",
        analysis_time = os.clock() - start,
        hash = hash,
    }
    
    -- Store in cache
    RecognitionCache.store(hash, result)
    
    return result
end

-- Process a binary through the cache
function RecognitionCache.process(binary_path)
    local cached, status, hash = RecognitionCache.check(binary_path)
    
    if cached then
        return cached, status, 0  -- 0 = no analysis time needed
    end
    
    -- Not cached - run full analysis
    local start = os.clock()
    local result = RecognitionCache.full_analysis(binary_path, hash)
    local analysis_time = os.clock() - start
    
    return result, status, analysis_time
end

return RecognitionCache
