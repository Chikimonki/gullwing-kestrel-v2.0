-- Test direct integration with Gullwing modules
package.path = "/mnt/d/moabi/src/?.lua;" .. package.path

local DirectIntegration = require("gullwing_direct_integration")

print("=== Direct Gullwing Integration Test ===\n")

-- Initialize
DirectIntegration.init()
print()

-- Check what modules are available
print("Module availability:")
for name, available in pairs({
    engine = DirectIntegration.has_module("engine"),
    analyzer = DirectIntegration.has_module("analyzer"),
    features = DirectIntegration.has_module("features"),
    memory = DirectIntegration.has_module("memory"),
    dynamic = DirectIntegration.has_module("dynamic"),
    diff = DirectIntegration.has_module("diff"),
}) do
    print(string.format("  %s: %s", name, available and "✓" or "✗"))
end
print()

-- List available functions
print("Available functions:")
local functions = DirectIntegration.list_functions()
for module_name, funcs in pairs(functions) do
    if #funcs > 0 then
        print(string.format("  %s:", module_name))
        for _, func in ipairs(funcs) do
            print(string.format("    - %s", func))
        end
    end
end
print()

-- Test binary analysis
local test_binary = "/bin/ls"
print(string.format("Analyzing: %s", test_binary))

local results = DirectIntegration.analyze_binary(test_binary)

if results then
    if results.gullwing then
        print("  ✓ Gullwing module analysis completed")
    end
    
    if results.kestrel then
        print("  ✓ Kestrel analysis completed")
        for expert_name, _ in pairs(results.kestrel) do
            print(string.format("    - %s", expert_name))
        end
    end
end

-- Cleanup
DirectIntegration.deinit()
print("\n✓ Cleanup complete")
print("\n=== Direct Integration Test Complete ===")
