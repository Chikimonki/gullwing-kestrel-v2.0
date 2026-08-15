package.path = "/mnt/d/moabi/gullwing-kestrel/accelerator/?.lua;" .. package.path

local PolicyLayer = require("policy_layer")

print("=== Phase 4: LuaJIT Policy Layer ===")
print()

-- Demonstrate hot-swappable policies
local scores = {0.8, 0.3, 0.6, 0.2, 0.9, 0.1, 0.7, 0.4}
local context = {top_k = 2, cached_experts = {[1]=true, [3]=true}}

print("Expert scores: {0.8, 0.3, 0.6, 0.2, 0.9, 0.1, 0.7, 0.4}")
print()

-- Try each policy
for name, _ in pairs(PolicyLayer.policies) do
    PolicyLayer.set_policy(name)
    local selected = PolicyLayer.route(scores, context)
    print(string.format("  %-15s → selects experts: %s", name, table.concat(selected, ", ")))
end

print()
PolicyLayer.benchmark_switching()
