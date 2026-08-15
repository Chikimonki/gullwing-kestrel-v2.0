-- Test real binary feature extraction
package.path = "/mnt/d/moabi/gullwing-kestrel/?.lua;/mnt/d/moabi/gullwing-kestrel/02-router/?.lua;" .. package.path

local BinaryFeatures = require("binary_features")

print("=== Binary Feature Extraction Test ===\n")

-- Read a real binary
local file = io.open("/bin/ls", "rb")
local content = file:read("*all")
file:close()

print(string.format("Binary: /bin/ls (%d bytes)", #content))
print()

-- Extract all features
local features = BinaryFeatures.extract_all(content)

print("Extracted Features:")
if features.elf then
    print(string.format("  ✓ ELF Features: %d extracted", #features.elf))
    print(string.format("    Class: %s", features.elf[1] > 0.5 and "64-bit" or "32-bit"))
    print(string.format("    Type: %s", features.elf[4] > 0.1 and "Executable" or "Other"))
end

if features.entropy then
    print(string.format("  ✓ Entropy: %d features", #features.entropy))
    print(string.format("    Global entropy: %.2f bits/byte", features.entropy[1] * 8))
    print(string.format("    Window 1: %.2f", features.entropy[2] * 8))
    print(string.format("    Window 2: %.2f", features.entropy[3] * 8))
end

if features.ml then
    print(string.format("  ✓ ML Features: %d extracted", #features.ml))
end

if features.strings then
    print(string.format("  ✓ Strings: %d found", #features.strings))
    print("    Sample strings:")
    for i = 1, math.min(5, #features.strings) do
        print(string.format("      - %s", features.strings[i]))
    end
end

print("\n=== Feature Extraction Complete ===")
