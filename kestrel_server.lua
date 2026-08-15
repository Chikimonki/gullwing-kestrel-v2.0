-- kestrel_server.lua — HTTP API server for Kestrel v2.0
-- Serves analysis results to unified.html
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path

local socket = require("socket")
local IntegratedRouter = require("integrated_router")
local json = require("json")

local KestrelServer = {
    host = "127.0.0.1",
    port = 9394,  -- Different port to avoid conflicts
    router = IntegratedRouter,
    running = false,
}

-- JSON response helper
function KestrelServer.json_response(data, status)
    status = status or 200
    local body = json.encode(data)
    return {
        status = status,
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #body,
            ["Access-Control-Allow-Origin"] = "*",
        },
        body = body,
    }
end

-- Handle API endpoints
function KestrelServer.handle_request(method, path, query, body)
    -- Health check
    if path == "/health" then
        return KestrelServer.json_response({
            status = "healthy",
            engine = "kestrel-v2.0",
            version = "2.0",
            experts = KestrelServer.router.ctx.num_experts,
            memory_mb = tonumber(KestrelServer.router.ctx.used_memory) / 1024 / 1024,
            timestamp = os.time(),
        })
    end
    
    -- Analyze binary
    if path == "/analyze" then
        local binary_path = query.path or query.file
        
        if not binary_path then
            return KestrelServer.json_response({
                error = "Missing 'path' parameter",
            }, 400)
        end
        
        -- Check if file exists
        local file = io.open(binary_path, "rb")
        if not file then
            return KestrelServer.json_response({
                error = "File not found: " .. binary_path,
            }, 404)
        end
        file:close()
        
        -- Analyze
        local analysis = KestrelServer.router.analyze_binary(binary_path)
        
        if analysis then
            return KestrelServer.json_response({
                success = true,
                analysis = analysis,
            })
        else
            return KestrelServer.json_response({
                error = "Analysis failed",
            }, 500)
        end
    end
    
    -- Get cached analysis
    if path == "/analysis" then
        local binary_path = query.path
        
        if binary_path and KestrelServer.router.analysis_cache[binary_path] then
            return KestrelServer.json_response({
                success = true,
                cached = true,
                analysis = KestrelServer.router.analysis_cache[binary_path],
            })
        end
        
        -- Return all cached
        return KestrelServer.json_response({
            success = true,
            cached_analyses = KestrelServer.router.analysis_cache,
        })
    end
    
    -- List experts
    if path == "/experts" then
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
        
        return KestrelServer.json_response({
            success = true,
            experts = experts,
        })
    end
    
    -- Stats
    if path == "/stats" then
        return KestrelServer.json_response({
            success = true,
            stats = {
                experts_loaded = KestrelServer.router.ctx.num_experts,
                memory_used_mb = tonumber(KestrelServer.router.ctx.used_memory) / 1024 / 1024,
                total_memory_gb = tonumber(KestrelServer.router.ctx.total_memory) / 1024 / 1024 / 1024,
                cached_analyses = #KestrelServer.router.analysis_cache,
            },
        })
    end
    
    -- Default 404
    return KestrelServer.json_response({
        error = "Not found",
        path = path,
    }, 404)
end

-- Parse HTTP request
function KestrelServer.parse_request(client)
    client:settimeout(5)
    
    local request_line = client:receive("*l")
    if not request_line then
        return nil
    end
    
    local method, path_query = request_line:match("^(%w+)%s+(%S+)")
    if not method then
        return nil
    end
    
    -- Parse path and query
    local path, query_string = path_query:match("^([^?]*)%??(.*)$")
    local query = {}
    if query_string and #query_string > 0 then
        for key, value in query_string:gmatch("([^&]+)=([^&]+)") do
            query[key] = value
        end
    end
    
    -- Read headers
    local headers = {}
    local line = client:receive("*l")
    while line and #line > 0 do
        local key, value = line:match("^([^:]+):%s*(.*)$")
        if key then
            headers[key:lower()] = value
        end
        line = client:receive("*l")
    end
    
    -- Read body if content-length
    local body = ""
    if headers["content-length"] then
        local len = tonumber(headers["content-length"])
        if len and len > 0 then
            body = client:receive(len)
        end
    end
    
    return method, path, query, body
end

-- Send HTTP response
function KestrelServer.send_response(client, response)
    local status_text = "OK"
    if response.status == 400 then status_text = "Bad Request"
    elseif response.status == 404 then status_text = "Not Found"
    elseif response.status == 500 then status_text = "Internal Server Error"
    end
    
    client:send(string.format("HTTP/1.1 %d %s\r\n", response.status, status_text))
    
    for key, value in pairs(response.headers) do
        client:send(string.format("%s: %s\r\n", key, value))
    end
    
    client:send("\r\n")
    client:send(response.body or "")
end

-- Main server loop
function KestrelServer.start()
    if KestrelServer.running then
        return
    end
    
    -- Initialize router
    print("Initializing Kestrel v2.0...")
    KestrelServer.router.init(16 * 1024 * 1024 * 1024)
    
    -- Create server
    local server = assert(socket.bind(KestrelServer.host, KestrelServer.port))
    server:settimeout(1)
    
    KestrelServer.running = true
    
    print(string.format("✓ Kestrel API server running on http://%s:%d", 
          KestrelServer.host, KestrelServer.port))
    print(string.format("  Endpoints:"))
    print(string.format("  - GET /health       Health check"))
    print(string.format("  - GET /analyze?path=/bin/ls  Analyze binary"))
    print(string.format("  - GET /experts      List experts"))
    print(string.format("  - GET /stats        System stats"))
    print()
    
    while KestrelServer.running do
        local client = server:accept()
        
        if client then
            -- Handle request in coroutine
            local co = coroutine.create(function()
                local method, path, query, body = KestrelServer.parse_request(client)
                
                if method and path then
                    local response = KestrelServer.handle_request(method, path, query, body)
                    KestrelServer.send_response(client, response)
                end
                
                client:close()
            end)
            
            local ok, err = coroutine.resume(co)
            if not ok then
                print("Error handling request: " .. tostring(err))
                client:close()
            end
        end
    end
    
    server:close()
end

-- Stop server
function KestrelServer.stop()
    KestrelServer.running = false
    KestrelServer.router.deinit()
end

return KestrelServer
