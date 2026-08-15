-- deep_analysis.lua — Deep analysis for large binaries
local DeepAnalysis = {}

-- Analyze large binary with library dependencies
function DeepAnalysis.analyze_large_binary(binary_path)
    local results = {
        path = binary_path,
        dependencies = {},
        libraries = {},
        total_size = 0,
        analysis_time = 0,
    }
    
    local start_time = os.clock()
    
    -- Get file size
    local handle = io.popen("stat -c%s " .. binary_path .. " 2>/dev/null")
    local size_str = handle:read("*a")
    handle:close()
    results.total_size = tonumber(size_str) or 0
    
    -- Get dynamic dependencies
    handle = io.popen("ldd " .. binary_path .. " 2>/dev/null")
    local ldd_output = handle:read("*a")
    handle:close()
    
    -- Parse dependencies
    for line in ldd_output:gmatch("[^\n]+") do
        local lib = line:match("%s*(%S+)%s*=>")
        if lib then
            table.insert(results.dependencies, lib)
            table.insert(results.libraries, lib)
        end
    end
    
    -- Count total libraries
    results.library_count = #results.libraries
    
    -- Analyze each library
    for i, lib in ipairs(results.libraries) do
        local lib_handle = io.popen("stat -c%s " .. lib .. " 2>/dev/null")
        local lib_size = lib_handle:read("*a")
        lib_handle:close()
        
        results.libraries[i] = {
            name = lib,
            size = tonumber(lib_size) or 0,
        }
    end
    
    results.analysis_time = os.clock() - start_time
    
    return results
end

return DeepAnalysis
