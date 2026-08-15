local DeepIntegration = require("gullwing_deep_integration")

print("=== Deep Gullwing-Kestrel Integration Test ===\n")

-- Initialize
DeepIntegration.init()
print()

-- Test with real binaries
local test_binaries = {
    "/bin/ls",
    "/bin/cat",
    "/usr/bin/file",
    "/bin/bash",
}

print("Analyzing binaries through 8-layer convergent model:\n")

for _, binary in ipairs(test_binaries) do
    local file = io.open(binary, "rb")
    if file then
        file:close()
        
        print(string.format("Analyzing: %s", binary))
        local analysis = DeepIntegration.analyze_binary(binary)
        
        if analysis then
            DeepIntegration.print_report(analysis)
            print("\n")
        end
    end
end

-- Test cached analysis
print("Testing cached analysis:")
local cached = DeepIntegration.get_analysis("/bin/ls")
if cached then
    print(string.format("  ✓ Retrieved cached analysis for /bin/ls"))
    print(string.format("  Verdict: %s", cached.convergence.verdict))
end

print()

-- Cleanup
DeepIntegration.deinit()
print("✓ Cleanup complete")
print("\n=== Deep Integration Test Complete ===")
