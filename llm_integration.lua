-- llm_integration.lua — Real Phi-4-mini LLM integration
local LLMIntegration = {}

-- Check if Ollama is available
function LLMIntegration.check_ollama()
    local handle = io.popen("curl -s -m 2 http://127.0.0.1:11434/api/tags 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    
    return result and #result > 0
end

-- Generate interpretation using Phi-4-mini
function LLMIntegration.interpret_analysis(analysis)
    -- Build prompt
    local prompt = string.format([[
You are a binary security analyst. Analyze this binary:

File: %s
Size: %d bytes
Risk Score: %.3f
Verdict: %s

Provide:
1) Classification
2) Inherent risks
3) Linkage context
]], analysis.path, analysis.size, analysis.risk_score, analysis.verdict)
    
    -- Call Ollama
    local json_body = string.format('{"model":"phi4-mini","prompt":"%s","stream":false}', prompt:gsub('"', '\\"'))
    
    local cmd = string.format("curl -s -m 30 -X POST http://127.0.0.1:11434/api/generate -d '%s'", json_body)
    
    local handle = io.popen(cmd .. " 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    
    if result and #result > 0 then
        -- Extract response
        local response = result:match('"response":"([^"]+)"')
        if response then
            return response
        end
    end
    
    return nil
end

return LLMIntegration
