-- bench.lua — Kestrel v2.0 Benchmark Suite
local ffi = require("ffi")
local Router = require("../02-router/router")

-- Benchmark utilities
local Bench = {
    results = {},
}

function Bench.measure(name, fn, iterations)
    iterations = iterations or 1000
    
    -- Warm-up
    for i = 1, 100 do
        fn()
    end
    
    -- Measure
    local start = os.clock()
    for i = 1, iterations do
        fn()
    end
    local elapsed = os.clock() - start
    
    local avg_ms = (elapsed / iterations) * 1000
    local ops_per_sec = iterations / elapsed
    
    Bench.results[name] = {
        avg_ms = avg_ms,
        ops_per_sec = ops_per_sec,
        total_s = elapsed,
        iterations = iterations,
    }
    
    print(string.format(
        "%-30s %10.3f ms/op  %10.0f ops/s",
        name, avg_ms, ops_per_sec
    ))
end

-- Initialize router
print("=== Kestrel v2.0 Benchmark Suite ===\n")
print("Initializing router...")
Router.init(1024 * 1024 * 1024) -- 1GB for testing

-- Load test experts
print("Loading test experts...")
for i = 1, 8 do
    local expert_data = string.rep(string.char(i), 1024 * 1024) -- 1MB
    Router.load_expert(i, expert_data, i <= 2) -- First 2 are hot
end

-- Test hidden states
local hidden_states = {}
for i = 1, 512 do
    hidden_states[i] = math.random()
end

-- Benchmark routing
print("\n--- Routing Benchmarks ---")
Bench.measure("Single expert routing", function()
    Router.route(hidden_states)
end, 100)

Bench.measure("Batch routing (x10)", function()
    for i = 1, 10 do
        Router.route(hidden_states)
    end
end, 10)

-- Benchmark expert scoring
print("\n--- Expert Scoring ---")
local expert = Router.experts[1]

Bench.measure("Expert scoring", function()
    local score = 0
    for i = 1, #hidden_states do
        score = score + hidden_states[i] * 0.1
    end
end, 10000)

-- Memory usage
print("\n--- Memory Usage ---")
local mem_usage = Router.memory_usage()
print(string.format("Total memory: %.2f MB", mem_usage / 1024 / 1024))

-- Compare against baseline C implementation
print("\n=== Comparison with Vincenzo's C ===")
print("(Run separately with colibri benchmarks)")
print("Target: 2-5x speedup on routing")
print("Target: Sub-25GB memory usage")

-- Cleanup
Router.deinit()

print("\n=== Benchmark Complete ===")
