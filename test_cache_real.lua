package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;/mnt/d/moabi/src/?.lua;" .. package.path

local RouterWithCache = require("router_with_cache")

print("=== Kestrel Router with Recognition Cache ===")
print()

RouterWithCache.init()
print()

local binaries = {
    "/bin/ls",
    "/bin/cat",
    "/usr/bin/file",
    "/bin/ls",
    "/bin/cat",
    "/bin/bash",
    "/bin/grep",
    "/bin/ls",
}

print("Analysing binaries...")
print()

local total_analysis_time = 0
local total_cloak_time = 0

for i, binary in ipairs(binaries) do
    local start = os.clock()
    local result, status = RouterWithCache.analyse(binary)
    local elapsed = os.clock() - start
    
    if status == "cloaked" then
        print(string.format("  %d. %s → CLOAKED (%.4f ms)", i, binary, elapsed * 1000))
        total_cloak_time = total_cloak_time + elapsed
    else
        local verdict = result and result.convergence.verdict or "FAILED"
        print(string.format("  %d. %s → ANALYSED (%.4f ms) → %s", i, binary, elapsed * 1000, verdict))
        total_analysis_time = total_analysis_time + elapsed
    end
end

print()

local stats = RouterWithCache.get_stats()
print("=== Results ===")
print(string.format("Total: %d", stats.total_requests))
print(string.format("Cloaked: %d (%.1f%%)", stats.cloaked, stats.cloak_rate_percent))
print(string.format("Analysed: %d", stats.analysed))
print(string.format("Cache size: %d", stats.cache_size))
print()

print("=== Time Analysis ===")
print(string.format("Total analysis time: %.4f ms", total_analysis_time * 1000))
print(string.format("Total cloak time: %.4f ms", total_cloak_time * 1000))

if stats.analysed > 0 then
    local avg_analysis = total_analysis_time / stats.analysed
    local avg_cloak = total_cloak_time / math.max(stats.cloaked, 1)
    local speedup = avg_analysis / math.max(avg_cloak, 0.000001)
    
    print(string.format("Average analysis: %.4f ms", avg_analysis * 1000))
    print(string.format("Average cloak: %.4f ms", avg_cloak * 1000))
    print(string.format("Speedup for known binaries: %.1fx", speedup))
end
