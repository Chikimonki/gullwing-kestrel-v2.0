-- Test fully integrated router with real features and weights
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;" .. package.path

local IntegratedRouter = require("integrated_router")

print("=== Kestrel v2.0 Full Integration Test ===\n")

-- Initialize
IntegratedRouter.init()
print()

-- Test with real binaries
local test_binaries = {
    "/bin/ls",
    "/bin/cat",
    "/usr/bin/file",
}

for _, binary in ipairs(test_binaries) do
    print(string.format("Analyzing: %s", binary))
    
    local analysis = IntegratedRouter.analyze_binary(binary)
    
    if analysis then
        IntegratedRouter.print_report(analysis)
        print("\n")
    end
end

-- Performance summary
print("Performance Summary:")
print(string.format("  Experts: %d", IntegratedRouter.ctx.num_experts))
print(string.format("  Memory: %.2f MB", 
      tonumber(IntegratedRouter.ctx.used_memory) / 1024 / 1024))
print()

-- Cleanup
IntegratedRouter.deinit()
print("✓ Cleanup complete")
print("\n=== Full Integration Test Complete ===")
