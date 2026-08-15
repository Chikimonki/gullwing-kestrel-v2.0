package.path = "/mnt/d/moabi/gullwing-kestrel/accelerator/?.lua;" .. package.path

local PolicyLayerV2 = require("policy_layer_v2")

print("=== Policy Layer v2 — With Event Logging ===")
print()

local scores = {0.8, 0.3, 0.6, 0.2, 0.9, 0.1, 0.7, 0.4}
local context = {top_k = 2, cached_experts = {[1]=true, [3]=true}}

-- Exercise the policies with logging
print("1. Testing policies with event logging...")
for name, _ in pairs(PolicyLayerV2.policies) do
    PolicyLayerV2.set_policy(name)
    local selected = PolicyLayerV2.route(scores, context)
    print(string.format("   %-15s → experts: %s", name, table.concat(selected, ", ")))
end
print()

-- Show the event log summary
local summary = PolicyLayerV2.get_log_summary()
print("2. Event Log Summary:")
print(string.format("   Total events: %d", summary.total_events))
print(string.format("   Routing events: %d", summary.routing_events))
print(string.format("   Policy switches: %d", summary.policy_switch_events))
print(string.format("   Routes executed: %d", summary.stats.routes_executed))
print()

-- Demonstrate audit replay
print("3. Audit Trail (last 5 events):")
local events = require("event_log").replay()
for i = math.max(1, #events - 4), #events do
    local e = events[i]
    print(string.format("   [%d] %s at %s", e.id, e.type, os.date("%H:%M:%S", e.timestamp)))
end
print()

print("=== Event Logging Complete ===")
