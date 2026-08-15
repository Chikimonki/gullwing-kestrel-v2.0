local GullwingAPI = require("gullwing_api_integration")

print("=== Gullwing API Integration Test ===\n")

-- Initialize (will try to connect to Gullwing API)
local initialized = GullwingAPI.init()
if not initialized then
    print("Could not initialize Gullwing API integration")
    print("Falling back to local analysis...")
end

print()

-- Test with actual binaries
local test_binaries = {"/bin/ls", "/bin/cat"}

for _, binary in ipairs(test_binaries) do
    print(string.format("Analyzing: %s", binary))
    
    local result = GullwingAPI.analyze_binary(binary)
    
    if result then
        if result.combined then
            print("  ✓ Combined Gullwing + Kestrel analysis")
        else
            print("  ✓ Local Kestrel analysis")
            if result.kestrel_analysis then
                for name, _ in pairs(result.kestrel_analysis) do
                    print(string.format("    - %s layer analyzed", name))
                end
            end
        end
    else
        print("  ✗ Analysis failed")
    end
    
    print()
end

-- Cleanup
GullwingAPI.deinit()
print("✓ Cleanup complete")
print("\n=== API Integration Test Complete ===")
