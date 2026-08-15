-- event_log.lua — Append-only session log like DeepSeek's Harness
local EventLog = {
    events = {},
    next_id = 1,
}

function EventLog.append(event_type, data)
    local event = {
        id = EventLog.next_id,
        type = event_type,
        timestamp = os.time(),
        data = data,
    }
    EventLog.next_id = EventLog.next_id + 1
    table.insert(EventLog.events, event)
    return event.id
end

-- Specific event types
function EventLog.log_routing(scores, selected, policy)
    return EventLog.append("routing", {
        scores = scores,
        selected = selected,
        policy = policy,
    })
end

function EventLog.log_cache_hit(binary_path, hash)
    return EventLog.append("cache_hit", {
        path = binary_path,
        hash = hash,
    })
end

function EventLog.log_policy_switch(from, to)
    return EventLog.append("policy_switch", {
        from = from,
        to = to,
    })
end

-- Replay for audit
function EventLog.replay(filter_type)
    local filtered = {}
    for _, event in ipairs(EventLog.events) do
        if not filter_type or event.type == filter_type then
            table.insert(filtered, event)
        end
    end
    return filtered
end

return EventLog
