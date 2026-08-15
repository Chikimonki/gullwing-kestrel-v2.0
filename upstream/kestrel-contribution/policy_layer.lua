-- policy_layer.lua — Hot-swappable routing policy for expert selection
-- Colibri must recompile to change policy; Kestrel changes it live via LuaJIT

local PolicyLayer = {
    policies = {},
    active_policy = "balanced",
    stats = {
        policy_switches = 0,
        prefetch_hits = 0,
        prefetch_misses = 0,
    },
}

-- Policy 1: Balanced (default) — equal weight to all experts
function PolicyLayer.policies.balanced(expert_scores, context)
    local selected = {}
    local top_k = context.top_k or 2
    
    -- Sort by score and take top_k
    local indices = {}
    for i = 1, #expert_scores do
        indices[i] = i
    end
    
    table.sort(indices, function(a, b) 
        return expert_scores[a] > expert_scores[b]
    end)
    
    for i = 1, math.min(top_k, #indices) do
        selected[#selected + 1] = indices[i]
    end
    
    return selected
end

-- Policy 2: Greedy — always pick the single best expert
function PolicyLayer.policies.greedy(expert_scores, context)
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

-- Policy 3: Diverse — pick experts with different specialisations
function PolicyLayer.policies.diverse(expert_scores, context)
    local selected = {}
    local top_k = context.top_k or 2
    
    -- Sort by score
    local indices = {}
    for i = 1, #expert_scores do
        indices[i] = i
    end
    table.sort(indices, function(a, b) return expert_scores[a] > expert_scores[b] end)
    
    -- Pick top_k but with a diversity penalty on similar experts
    selected[1] = indices[1]
    for i = 2, math.min(top_k, #indices) do
        local candidate = indices[i]
        local is_similar = false
        
        for _, existing in ipairs(selected) do
            -- Experts that are adjacent (similar) get penalised
            if math.abs(candidate - existing) <= 1 then
                is_similar = true
                break
            end
        end
        
        if not is_similar then
            selected[#selected + 1] = candidate
        end
    end
    
    return selected
end

-- Policy 4: Cache-aware — prefer experts already in cache
function PolicyLayer.policies.cache_aware(expert_scores, context)
    local selected = {}
    local top_k = context.top_k or 2
    local cached_experts = context.cached_experts or {}
    
    -- Boost scores for cached experts (avoid disk reads)
    local adjusted_scores = {}
    for i = 1, #expert_scores do
        adjusted_scores[i] = expert_scores[i]
        if cached_experts[i] then
            adjusted_scores[i] = adjusted_scores[i] * 1.5  -- 50% boost for cached
        end
    end
    
    -- Sort adjusted scores
    local indices = {}
    for i = 1, #adjusted_scores do
        indices[i] = i
    end
    table.sort(indices, function(a, b) return adjusted_scores[a] > adjusted_scores[b] end)
    
    for i = 1, math.min(top_k, #indices) do
        selected[#selected + 1] = indices[i]
    end
    
    return selected
end

-- Set active policy at runtime (no recompile!)
function PolicyLayer.set_policy(name)
    if PolicyLayer.policies[name] then
        PolicyLayer.active_policy = name
        PolicyLayer.stats.policy_switches = PolicyLayer.stats.policy_switches + 1
        print(string.format("  ✓ Policy switched to: %s", name))
        return true
    end
    return false
end

-- Route experts using the active policy
function PolicyLayer.route(expert_scores, context)
    local policy = PolicyLayer.policies[PolicyLayer.active_policy]
    return policy(expert_scores, context or {})
end

-- Benchmark policy switching (the key Kestrel advantage)
function PolicyLayer.benchmark_switching()
    print("=== Policy Switching Benchmark ===")
    print()
    
    local scores = {0.8, 0.3, 0.6, 0.2, 0.9, 0.1, 0.7, 0.4}
    local context = {top_k = 2, cached_experts = {[1]=true, [3]=true}}
    
    -- Time each policy
    for name, _ in pairs(PolicyLayer.policies) do
        PolicyLayer.set_policy(name)
        
        local start = os.clock()
        for iter = 1, 10000 do
            PolicyLayer.route(scores, context)
        end
        local elapsed = (os.clock() - start) * 1000
        
        print(string.format("  %-15s: %.3f ms for 10,000 routes (%.3f μs/route)", 
              name, elapsed, elapsed / 10))
    end
    
    print()
    print(string.format("Total policy switches: %d", PolicyLayer.stats.policy_switches))
    print()
    print("=== Key Advantage ===")
    print("Colibri: Change policy = edit C = recompile = restart")
    print("Kestrel: Change policy = set_policy('name') = instant")
end

return PolicyLayer
