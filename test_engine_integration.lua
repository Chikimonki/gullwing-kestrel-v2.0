-- Test Kestrel v2.0 with moabi-engine.lua
-- Add paths for both Gullwing source and Kestrel modules
package.path = "/mnt/d/moabi/src/?.lua;/mnt/d/moabi/gullwing-kestrel/?.lua;" .. package.path

local EngineIntegration = require("gullwing_engine_integration")

print("=== Kestrel v2.0 + moabi-engine Integration Test ===\n")

-- Initialize
EngineIntegration.init()
print()

-- Test prompt building
local test_binary = "/bin/ls"
print(string.format("Building analysis prompt for: %s", test_binary))

local prompt = EngineIntegration.build_binary_prompt(test_binary)
if prompt then
    print("\nGenerated Prompt (first 500 chars):")
    print(string.sub(prompt, 1, 500) .. "...")
    print()
end

-- Test binary analysis
print(string.format("Analyzing binary: %s", test_binary))
local analysis = EngineIntegration.analyze_binary(test_binary)

if analysis then
    print("\nAnalysis Results:")
    for expert_id, result in pairs(analysis) do
        local expert = EngineIntegration.experts[expert_id]
        if expert then
            print(string.format("  ✓ %s: confidence=%.2f", 
                  expert.name, result.confidence))
        end
    end
end

-- Get engine config
print("\nEngine Configuration:")
local config = EngineIntegration.get_config()
for key, value in pairs(config) do
    print(string.format("  %s: %s", key, tostring(value)))
end

-- Cleanup
print()
EngineIntegration.deinit()
print("✓ Cleanup complete")
print("\n=== Engine Integration Test Complete ===")
