-- Test real expert weight loading
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;" .. package.path

local RouterV2 = require("router_v2")

print("=== Kestrel v2.0 Real Weight Test ===\n")

-- Initialize with 16GB (for your current system)
RouterV2.init(16 * 1024 * 1024 * 1024)
print()

-- Create experts with real dimensions
print("Creating experts with real matrix dimensions:")
RouterV2.create_expert(1, 512, 128, true)   -- ELF Analysis: 512 features → 128 outputs
RouterV2.create_expert(2, 512, 128, true)   -- PE Analysis
RouterV2.create_expert(3, 256, 64, true)    -- Entropy: 256 features → 64 outputs
RouterV2.create_expert(4, 128, 32, true)    -- ML Classification
RouterV2.create_expert(5, 256, 64, false)   -- Runtime
RouterV2.create_expert(6, 256, 64, false)   -- Memory
RouterV2.create_expert(7, 256, 64, false)   -- Memory Diff
RouterV2.create_expert(8, 512, 128, false)  -- SBOM
print()

-- Test forward pass with real computation
print("Testing forward pass with real matrix multiplication:")
local input = {}
for i = 1, 512 do
    input[i] = math.random()
end

local output = RouterV2.forward(1, input)
if output then
    print(string.format("  ✓ Expert 1: %d outputs computed", #output))
    print(string.format("    First 5 outputs: %.4f, %.4f, %.4f, %.4f, %.4f", 
          output[1], output[2], output[3], output[4], output[5]))
end

-- Test with smaller expert
local input_small = {}
for i = 1, 128 do
    input_small[i] = math.random()
end

local output4 = RouterV2.forward(4, input_small)
if output4 then
    print(string.format("  ✓ Expert 4: %d outputs computed", #output4))
    print(string.format("    First 3 outputs: %.4f, %.4f, %.4f", 
          output4[1], output4[2], output4[3]))
end
print()

-- Memory usage
print(string.format("Memory used: %.2f MB", 
      tonumber(RouterV2.ctx.used_memory) / 1024 / 1024))
print(string.format("Experts loaded: %d", tonumber(RouterV2.ctx.num_experts)))
print()

-- Performance benchmark
print("Performance benchmark:")
local start = os.clock()
for i = 1, 1000 do
    RouterV2.forward(1, input)
end
local elapsed = os.clock() - start
print(string.format("  ✓ 1000 forward passes: %.3f seconds", elapsed))
print(string.format("  ✓ Average: %.3f ms/pass", (elapsed / 1000) * 1000))
print()

-- Cleanup
RouterV2.deinit()
print("✓ Cleanup complete")
print("\n=== Real Weight Test Complete ===")
