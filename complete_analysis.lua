package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path

local IntegratedRouter = require("integrated_router")

local CompleteAnalysis = {
    router = IntegratedRouter,
    solver_path = nil,
    ollama_url = "http://127.0.0.1:11434",
    initialized = false,
}

function CompleteAnalysis.init()
    if CompleteAnalysis.initialized then return end
    
    CompleteAnalysis.router.init(16 * 1024 * 1024 * 1024)
    CompleteAnalysis.initialized = true
    
    -- Dynamically find solver
    local handle = io.popen("bash /mnt/d/moabi/gullwing-kestrel/check_solver.sh 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    
    if result and result:match("^FOUND:") then
        CompleteAnalysis.solver_path = result:match("^FOUND:(.+)")
        CompleteAnalysis.solver_available = true
    elseif result and result:match("^DOCKER:") then
        CompleteAnalysis.solver_path = "docker run wsolver"
        CompleteAnalysis.solver_available = true
    else
        CompleteAnalysis.solver_available = false
    end
    
    -- Check Ollama
    local ollama_handle = io.popen("curl -s -m 2 http://127.0.0.1:11434/api/tags 2>/dev/null")
    local ollama_result = ollama_handle:read("*a")
    ollama_handle:close()
    CompleteAnalysis.ollama_available = ollama_result and ollama_result:match("phi4") ~= nil
    
    print(string.format("✓ Complete Analysis initialized"))
    print(string.format("  Solver: %s", CompleteAnalysis.solver_available and CompleteAnalysis.solver_path or "Not available"))
    print(string.format("  Phi-4-mini: %s", CompleteAnalysis.ollama_available and "Available" or "Not running"))
end

function CompleteAnalysis.analyze(binary_path)
    CompleteAnalysis.init()
    
    local result = {
        path = binary_path,
        kestrel = CompleteAnalysis.router.analyze_binary(binary_path),
        solver = nil,
        llm = nil,
        combined = nil,
    }
    
    -- Run Solver if available
    if CompleteAnalysis.solver_available and result.kestrel then
        result.solver = CompleteAnalysis.run_solver(binary_path)
    end
    
    -- Run LLM if available
    if CompleteAnalysis.ollama_available and result.kestrel then
        result.llm = CompleteAnalysis.interpret_with_llm(result.kestrel)
    end
    
    result.combined = CompleteAnalysis.combine_results(result)
    
    return result
end

function CompleteAnalysis.run_solver(binary_path)
    local cmd = CompleteAnalysis.solver_path .. " " .. binary_path .. " 2>&1"
    local handle = io.popen(cmd)
    local output = handle:read("*a")
    handle:close()
    
    local solver_result = {
        output = output:sub(1, 500),
        verdict = "UNKNOWN",
        violations = 0,
    }
    
    if output:match("UNSAFE%s+(%d+)") then
        solver_result.violations = tonumber(output:match("UNSAFE%s+(%d+)"))
        solver_result.verdict = "UNSAFE"
    elseif output:match("SAFE") then
        solver_result.verdict = "SAFE"
    end
    
    return solver_result
end

function CompleteAnalysis.interpret_with_llm(kestrel_result)
    local prompt = string.format(
        'Analyze binary: %s, size: %d bytes, risk: %.3f, verdict: %s. Provide brief security interpretation.',
        kestrel_result.path, kestrel_result.size, 
        kestrel_result.convergence.risk_score, 
        kestrel_result.convergence.verdict
    )
    
    prompt = prompt:gsub('"', '\\"'):gsub('\n', '\\n')
    
    local json_body = string.format(
        '{"model":"phi4-mini","prompt":"%s","stream":false}',
        prompt
    )
    
    local cmd = string.format(
        "curl -s -m 30 -X POST %s/api/generate -d '%s'",
        CompleteAnalysis.ollama_url, json_body
    )
    
    local handle = io.popen(cmd)
    local response = handle:read("*a")
    handle:close()
    
    local interpretation = response:match('"response":"([^"]+)"')
    return interpretation
end

function CompleteAnalysis.combine_results(result)
    local combined = {
        verdict = "BENIGN",
        confidence = 0,
    }
    
    if result.kestrel then
        combined.kestrel_risk = result.kestrel.convergence.risk_score
        combined.kestrel_verdict = result.kestrel.convergence.verdict
    end
    
    if result.solver then
        combined.solver_verdict = result.solver.verdict
        combined.solver_violations = result.solver.violations
    end
    
    if result.llm then
        combined.llm_interpretation = result.llm
    end
    
    if result.solver and result.solver.verdict == "UNSAFE" then
        combined.verdict = "HIGH RISK"
        combined.confidence = 0.9
    elseif result.kestrel and result.kestrel.convergence.risk_score > 0.5 then
        combined.verdict = "MODERATE RISK"
        combined.confidence = 0.7
    else
        combined.verdict = "BENIGN"
        combined.confidence = 0.9
    end
    
    return combined
end

return CompleteAnalysis
