-- router_with_cache.lua — Kestrel router with recognition cache
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path

local IntegratedRouter = require("integrated_router")

local RouterWithCache = {
    cache = {},
    cache_order = {},
    max_cache = 500,
    stats = {
        total = 0,
        cloaked = 0,
        analysed = 0,
    },
    router = IntegratedRouter,
}

-- Fast hash (JIT-compiled by LuaJIT)
local function fast_hash(data)
    local h = 5381
    for i = 1, #data do
        h = (h * 33 + data:byte(i)) % 2^32
    end
    return h
end

function RouterWithCache.init()
    RouterWithCache.router.init(16 * 1024 * 1024 * 1024)
end

function RouterWithCache.analyse(binary_path)
    RouterWithCache.stats.total = RouterWithCache.stats.total + 1
    
    -- Read first 8KB for fingerprint
    local file = io.open(binary_path, "rb")
    if not file then
        return nil, "File not found"
    end
    
    local fingerprint = file:read(8192)
    file:close()
    
    -- Compute hash
    local hash = fast_hash(fingerprint)
    
    -- Check cache FIRST (the cloak)
    if RouterWithCache.cache[hash] then
        RouterWithCache.stats.cloaked = RouterWithCache.stats.cloaked + 1
        
        local cached = RouterWithCache.cache[hash]
        cached.from_cache = true
        cached.cache_hit_count = (cached.cache_hit_count or 0) + 1
        
        return cached, "cloaked"
    end
    
    -- Not cached - full 8-layer analysis
    RouterWithCache.stats.analysed = RouterWithCache.stats.analysed + 1
    
    local result = RouterWithCache.router.analyze_binary(binary_path)
    
    if result then
        result.hash = hash
        result.from_cache = false
        result.cache_hit_count = 0
        
        RouterWithCache.cache[hash] = result
        table.insert(RouterWithCache.cache_order, hash)
        
        if #RouterWithCache.cache_order > RouterWithCache.max_cache then
            local oldest = table.remove(RouterWithCache.cache_order, 1)
            RouterWithCache.cache[oldest] = nil
        end
    end
    
    return result, "analysed"
end

function RouterWithCache.get_stats()
    local total = RouterWithCache.stats.total
    local cloak_rate = total > 0 and (RouterWithCache.stats.cloaked / total * 100) or 0
    
    return {
        total_requests = total,
        cloaked = RouterWithCache.stats.cloaked,
        analysed = RouterWithCache.stats.analysed,
        cloak_rate_percent = cloak_rate,
        cache_size = #RouterWithCache.cache_order,
    }
end

return RouterWithCache
