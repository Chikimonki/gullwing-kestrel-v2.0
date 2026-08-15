-- binary_features.lua — Real feature extraction from binaries
local ffi = require("ffi")

local BinaryFeatures = {}

-- Extract ELF header features
function BinaryFeatures.extract_elf_features(content)
    if #content < 64 then
        return nil, "File too small for ELF"
    end
    
    -- Check ELF magic
    if content:sub(1, 4) ~= "\127ELF" then
        return nil, "Not an ELF file"
    end
    
    local features = {}
    
    -- ELF header fields (first 64 bytes)
    features[1] = content:byte(5) / 255.0   -- Class (32/64 bit)
    features[2] = content:byte(6) / 255.0   -- Data encoding
    features[3] = content:byte(7) / 255.0   -- Version
    features[4] = content:byte(16) / 255.0  -- Type (executable, shared lib, etc.)
    features[5] = content:byte(18) / 255.0  -- Machine architecture
    
    -- Entry point (bytes 24-31 for 64-bit)
    local entry_lo = content:byte(24) + content:byte(25) * 256
    features[6] = (entry_lo % 255) / 255.0
    
    -- Section header offset
    local shoff_lo = content:byte(40) + content:byte(41) * 256
    features[7] = (shoff_lo % 255) / 255.0
    
    -- Add first 100 bytes as raw features
    for i = 1, math.min(100, #content) do
        features[8 + i] = content:byte(i) / 255.0
    end
    
    return features
end

-- Extract entropy features
function BinaryFeatures.extract_entropy(content)
    local features = {}
    
    -- Calculate byte frequency distribution
    local freq = {}
    for i = 0, 255 do
        freq[i] = 0
    end
    
    for i = 1, #content do
        local byte = content:byte(i)
        freq[byte] = (freq[byte] or 0) + 1
    end
    
    -- Shannon entropy (global)
    local entropy = 0.0
    local total = #content
    for i = 0, 255 do
        if freq[i] > 0 then
            local p = freq[i] / total
            entropy = entropy - p * math.log(p) / math.log(2)
        end
    end
    
    features[1] = entropy / 8.0  -- Normalize to 0-1 (8 bits max entropy)
    
    -- Windowed entropy (4 windows)
    local window_size = math.floor(#content / 4)
    for w = 0, 3 do
        local start = w * window_size + 1
        local end_pos = math.min(start + window_size - 1, #content)
        
        local window_freq = {}
        for i = 0, 255 do
            window_freq[i] = 0
        end
        
        for i = start, end_pos do
            local byte = content:byte(i)
            window_freq[byte] = (window_freq[byte] or 0) + 1
        end
        
        local window_entropy = 0.0
        local window_total = end_pos - start + 1
        for i = 0, 255 do
            if window_freq[i] > 0 then
                local p = window_freq[i] / window_total
                window_entropy = window_entropy - p * math.log(p) / math.log(2)
            end
        end
        
        features[2 + w] = window_entropy / 8.0
    end
    
    -- Byte distribution features (most common bytes)
    local sorted_bytes = {}
    for i = 0, 255 do
        table.insert(sorted_bytes, {byte = i, count = freq[i]})
    end
    
    table.sort(sorted_bytes, function(a, b) return a.count > b.count end)
    
    for i = 1, 10 do
        features[6 + i] = (sorted_bytes[i].byte or 0) / 255.0
        features[16 + i] = (sorted_bytes[i].count / total)
    end
    
    return features
end

-- Extract string features (for semantic analysis)
function BinaryFeatures.extract_strings(content, max_strings)
    max_strings = max_strings or 50
    local strings = {}
    
    -- Find printable strings (4+ chars)
    local current = {}
    local string_count = 0
    
    for i = 1, #content do
        local byte = content:byte(i)
        
        if byte >= 32 and byte <= 126 then
            table.insert(current, string.char(byte))
        else
            if #current >= 4 then
                string_count = string_count + 1
                strings[string_count] = table.concat(current)
                
                if string_count >= max_strings then
                    break
                end
            end
            current = {}
        end
    end
    
    return strings
end

-- Extract ML features (combine all)
function BinaryFeatures.extract_ml_features(content)
    local features = {}
    
    -- File size features
    features[1] = math.min(#content / (10 * 1024 * 1024), 1.0)  -- Size up to 10MB
    
    -- Entropy
    local entropy = BinaryFeatures.extract_entropy(content)
    for i = 1, #entropy do
        features[1 + i] = entropy[i]
    end
    
    -- ELF features if applicable
    local elf_features = BinaryFeatures.extract_elf_features(content)
    if elf_features then
        for i = 1, math.min(#elf_features, 100) do
            features[#features + 1] = elf_features[i]
        end
    end
    
    return features
end

-- Extract comprehensive features for routing
function BinaryFeatures.extract_all(content)
    local all_features = {}
    
    -- Try ELF
    local elf_features, elf_err = BinaryFeatures.extract_elf_features(content)
    if elf_features then
        all_features.elf = elf_features
    end
    
    -- Entropy
    all_features.entropy = BinaryFeatures.extract_entropy(content)
    
    -- ML features
    all_features.ml = BinaryFeatures.extract_ml_features(content)
    
    -- Strings
    all_features.strings = BinaryFeatures.extract_strings(content, 20)
    
    return all_features
end

return BinaryFeatures
