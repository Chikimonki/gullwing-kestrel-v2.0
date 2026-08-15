-- solver_integration.lua — Real Witchcraft Solver integration
local SolverIntegration = {}

-- Check if wsolver is available
function SolverIntegration.check_available()
    local handle = io.popen("which wsolve 2>/dev/null || ls ~/wsolver/wsolve 2>/dev/null || ls /mnt/d/moabi/wsolver/wsolve 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    
    return result and #result > 0
end

-- Run solver on binary
function SolverIntegration.run(binary_path, options)
    options = options or {}
    
    local cmd = "wsolve " .. binary_path
    
    if options.output_dir then
        cmd = cmd .. " " .. options.output_dir
    end
    
    -- Run solver (could take 25+ minutes for real analysis)
    local handle = io.popen(cmd .. " 2>&1")
    local output = handle:read("*a")
    local success = handle:close()
    
    return {
        success = success,
        output = output,
        command = cmd,
    }
end

-- Parse solver output
function SolverIntegration.parse_output(output)
    local result = {
        prefilter = {},
        violations = {},
        verdict = "UNKNOWN",
        confidence = "LOW",
    }
    
    -- Parse pre-filter results
    local bounded = output:match("BOUNDED%s+: (%d+)")
    local unknown = output:match("UNKNOWN%s+: (%d+)")
    
    if bounded then result.prefilter.bounded = tonumber(bounded) end
    if unknown then result.prefilter.unknown = tonumber(unknown) end
    
    -- Parse violations
    local unsafe = output:match("UNSAFE%s+(%d+)")
    if unsafe then result.violations.count = tonumber(unsafe) end
    
    -- Parse verdict
    if output:match("Verdict%s+: (%w+)") then
        result.verdict = output:match("Verdict%s+: (%w+)")
    end
    
    if output:match("Confidence%s+: (%w+)") then
        result.confidence = output:match("Confidence%s+: (%w+)")
    end
    
    return result
end

return SolverIntegration
