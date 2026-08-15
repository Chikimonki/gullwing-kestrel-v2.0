-- policy_layer_v2.lua — Policy layer with event logging (DeepSeek Harness pattern)
package.path = "/mnt/d/moabi/gullwing-kestrel/accelerator/?.lua;" .. package.path

local EventLog = require("event_log")

local PolicyLayerV2 = {
    policies = {},
    active_policy = "balanced",
    stats = {
        policy_switches = 0,
        routes_executed = 0,
        events_logged = 0,
    },
}

-- Policies (same as before, now with logging)
function PolicyLayerV2.policies.balanced(expert_scores, context)
    local selected = {}
    local top_k = context.top_k or 2
    local indices = {}
    for i = 1, #expert_scores do indices[i] = i end
    table.sort(indices, function(a, b) return expert_scores[a] > expert_scores[b] end)
    for i = 1, math.min(top_k, #indices) do selected[#selected+1] = indices[i] end
    return selected
end

function PolicyLayerV2.policies.greedy(expert_scores, context)
    local best_idx = 1
    local best_score = expert_scores[1]
    for i = 2, #expert_scores do
        if expert_scores[i] > best_score then
            best_score = expert_scores[i]
            best_idx = i
        end
    end
    return {best_idx}
end

function PolicyLayerV2.policies.diverse(expert_scores, context)
    local selected = {}
    local top_k = context.top_k or 2
    local indices = {}
    for i = 1, #expert_scores do indices[i] = i end
    table.sort(indices, function(a, b) return expert_scores[a] > expert_scores[b] end)
    selected[1] = indices[1]
    for i = 2, math.min(top_k, #indices) do
        local candidate = indices[i]
        local is_similar = false
        for _, existing in ipairs(selected) do
            if math.abs(candidate - existing) <= 1 then
                is_similar = true
                break
            end
        end
        if not is_similar then selected[#selected+1] = candidate end
    end
    return selected
end

function PolicyLayerV2.policies.cache_aware(expert_scores, context)
    local selected = {}
    local top_k = context.top_k or 2
    local cached = context.cached_experts or {}
    local adjusted = {}
    for i = 1, #expert_scores do
        adjusted[i] = expert_scores[i]
        if cached[i] then adjusted[i] = adjusted[i] * 1.5 end
    end
    local indices = {}
    for i = 1, #adjusted do indices[i] = i end
    table.sort(indices, function(a, b) return adjusted[a] > adjusted[b] end)
    for i = 1, math.min(top_k, #indices) do selected[#selected+1] = indices[i] end
    return selected
end

-- Set policy with logging
function PolicyLayerV2.set_policy(name)
    if PolicyLayerV2.policies[name] and name ~= PolicyLayerV2.active_policy then
        local old = PolicyLayerV2.active_policy
        PolicyLayerV2.active_policy = name
        PolicyLayerV2.stats.policy_switches = PolicyLayerV2.stats.policy_switches + 1
        
        -- Log the policy switch (DeepSeek Harness pattern)
        EventLog.log_policy_switch(old, name)
        PolicyLayerV2.stats.events_logged = PolicyLayerV2.stats.events_logged + 1
        
        print(string.format("  ✓ Policy: %s → %s (event logged)", old, name))
        return true
    end
    return false
end

-- Route with logging
function PolicyLayerV2.route(expert_scores, context)
    local policy = PolicyLayerV2.policies[PolicyLayerV2.active_policy]
    local selected = policy(expert_scores, context or {})
    
    PolicyLayerV2.stats.routes_executed = PolicyLayerV2.stats.routes_executed + 1
    
    -- Log every routing decision
    EventLog.log_routing(expert_scores, selected, PolicyLayerV2.active_policy)
    PolicyLayerV2.stats.events_logged = PolicyLayerV2.stats.events_logged + 1
    
    return selected
end

-- Get event log summary
function PolicyLayerV2.get_log_summary()
    local all_events = EventLog.replay()
    local routing_count = #EventLog.replay("routing")
    local switch_count = #EventLog.replay("policy_switch")
    
    return {
        total_events = #all_events,
        routing_events = routing_count,
        policy_switch_events = switch_count,
        stats = PolicyLayerV2.stats,
    }
end

return PolicyLayerV2
