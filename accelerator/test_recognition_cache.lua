-- Test the recognition cache with real binaries
package.path = "/mnt/d/moabi/gullwing-kestrel/accelerator/?.lua;" .. package.path

local RecognitionCache = require("recognition_cache")

print("=== Recognition Cache Test ===")
print()

-- Test binaries
local test_binaries = {
    "/bin/ls",
    "/bin/cat",
    "/bin/ls",     -- duplicate!
    "/usr/bin/file",
    "/bin/cat",    -- duplicate!
    "/bin/ls",     -- duplicate again!
}

print("Processing binaries (with duplicates)...")
print()

local total_time = 0
local cloaked_time = 0
local analysed_time = 0

for i, binary in ipairs(test_binaries) do
    local result, status, analysis_time = RecognitionCache.process(binary)
    
    if status == "cloaked" then
        print(string.format("  %d. %s → CLOAKED (instant)", i, binary))
        cloaked_time = cloaked_time + analysis_time
    else
        print(string.format("  %d. %s → ANALYSED (%.4f s)", i, binary, analysis_time))
        analysed_time = analysed_time + analysis_time
    end
    
    total_time = total_time + analysis_time
end

print()

-- Stats
local stats = RecognitionCache.get_stats()
print("=== Cache Statistics ===")
print(string.format("Total requests: %d", stats.total_requests))
print(string.format("Cloaked (cache hits): %d", stats.cloaked))
print(string.format("Analysed (new): %d", stats.analysed))
print(string.format("Cloak rate: %.1f%%", stats.cloak_rate_percent))
print(string.format("Cache size: %d", stats.cache_size))
print()

print("=== Time Comparison ===")
print(string.format("Total time: %.4f s", total_time))
print(string.format("Cloaked time: %.4f s", cloaked_time))
print(string.format("Analysed time: %.4f s", analysed_time))

if stats.analysed > 0 then
    local avg_analysis = analysed_time / stats.analysed
    local potential_savings = stats.cloaked * avg_analysis
    print(string.format("Average analysis: %.4f s", avg_analysis))
    print(string.format("Time saved by cloaking: %.4f s", potential_savings))
end
