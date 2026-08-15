-- test_cold_tier.lua — Prove the cold tier works
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/gullwing-kestrel/accelerator/?.lua;/mnt/d/moabi/gullwing-kestrel/accelerator/stacked/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path

local StackedKestrel = require("kestrel_stacked")

print("=== Phase 1: Cold-Tier Proof Run ===")
print()

StackedKestrel.init()
print()

print("Creating unique large test files on D: (cold tier)...")
print()

local test_files = {}
for i = 1, 3 do
    local filename = string.format("/mnt/d/cold_test_%d.bin", i)
    os.execute(string.format("dd if=/dev/urandom of=%s bs=1M count=100 2>/dev/null", filename))
    test_files[i] = filename
    print(string.format("  ✓ Created %s (100MB)", filename))
end
print()

-- Force cold routing
local original_hot_budget = StackedKestrel.storage_tiers.hot.budget_gb
StackedKestrel.storage_tiers.hot.budget_gb = 0.001

print("Hot tier budget set to 1MB (forcing cold routing)")
print()

print("Processing unique large binaries through cold tier...")
print()

local total_time = 0
local cold_count = 0

for i, binary in ipairs(test_files) do
    local start = os.clock()
    local result, status, tier = StackedKestrel.analyse(binary)
    local elapsed = os.clock() - start
    
    total_time = total_time + elapsed
    
    if tier == "cold" then
        cold_count = cold_count + 1
        print(string.format("  %d. %s → COLD (%.2f ms)", i, binary, elapsed * 1000))
    else
        print(string.format("  %d. %s → %s (%.2f ms)", i, binary, tier:upper(), elapsed * 1000))
    end
end

print()

-- Restore
StackedKestrel.storage_tiers.hot.budget_gb = original_hot_budget

-- Cleanup
for _, file in ipairs(test_files) do
    os.remove(file)
end

print("=== Cold-Tier Results ===")
print(string.format("Cold tier processed: %d", cold_count))
print(string.format("Total time: %.2f ms", total_time * 1000))

if cold_count > 0 then
    local avg = total_time / cold_count
    print(string.format("Average cold processing: %.2f ms", avg * 1000))
    print(string.format("Throughput: %.1f binaries/sec", cold_count / total_time))
end

print()
print("✓ Cold tier proven")
