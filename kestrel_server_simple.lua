-- kestrel_server_simple.lua — Simple HTTP server using netcat (no LuaSocket needed)
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path

local IntegratedRouter = require("integrated_router")
local json = require("json")

local KestrelServer = {
    router = IntegratedRouter,
    initialized = false,
}

-- Initialize router
function KestrelServer.init()
    if not KestrelServer.initialized then
        print("Initializing Kestrel v2.0...")
        KestrelServer.router.init(16 * 1024 * 1024 * 1024)
        KestrelServer.initialized = true
        print("✓ Kestrel ready")
    end
end

-- Handle analysis request
function KestrelServer.analyze(binary_path)
    KestrelServer.init()
    
    local analysis = KestrelServer.router.analyze_binary(binary_path)
    
    if analysis then
        return {
            success = true,
            analysis = analysis,
        }
    else
        return {
            error = "Analysis failed",
        }
    end
end

-- Get health status
function KestrelServer.health()
    KestrelServer.init()
    
    return {
        status = "healthy",
        engine = "kestrel-v2.0",
        experts = KestrelServer.router.ctx.num_experts,
        memory_mb = tonumber(KestrelServer.router.ctx.used_memory) / 1024 / 1024,
    }
end

-- Get experts list
function KestrelServer.get_experts()
    KestrelServer.init()
    
    local experts = {}
    for id, expert in pairs(KestrelServer.router.experts) do
        experts[#experts + 1] = {
            id = id,
            name = expert.name,
            input_dim = expert.input_dim,
            output_dim = expert.output_dim,
            hot = expert.hot,
        }
    end
    
    return {
        success = true,
        experts = experts,
    }
end

return KestrelServer
