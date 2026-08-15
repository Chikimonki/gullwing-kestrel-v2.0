local GullwingKestrel = require("gullwing_integration")

print("=== Gullwing-Kestrel Integration Test ===\n")

-- Initialize
GullwingKestrel.init()
print()

-- Test with a real binary
local test_binary = "/bin/ls"  -- Use a real binary
print("Analyzing binary:", test_binary)

local results = GullwingKestrel.analyze_binary(test_binary)

if results then
    print("\nAnalysis Results:")
    if results.elf_header then
        print("  ✓ ELF Header Analysis complete")
    end
    if results.entropy then
        print("  ✓ Entropy Detection complete")
    end
    if results.ml_classification then
        print("  ✓ ML Classification complete")
    end
end

-- Get summary
local summary = GullwingKestrel.get_summary(test_binary)
if summary then
    print("\nAnalysis Summary:")
    print(string.format("  File: %s", summary.path))
    print(string.format("  Size: %d bytes", summary.size))
    print(string.format("  Experts used: %d", summary.experts_used))
    print(string.format("  Memory used: %.2f MB", summary.total_memory_mb))
end

-- Test with multiple binaries
print("\nTesting multiple binaries...")
local binaries = {"/bin/ls", "/bin/cat", "/usr/bin/file"}
for _, binary in ipairs(binaries) do
    local file = io.open(binary, "rb")
    if file then
        file:close()
        local result = GullwingKestrel.analyze_binary(binary)
        print(string.format("  ✓ Analyzed: %s", binary))
    end
end

-- Cleanup
GullwingKestrel.deinit()
print("\n✓ Cleanup complete")
print("\n=== Integration Test Complete ===")
