#!/bin/bash

echo "=== Testing Kestrel v2.0 ==="

# Build
./build.sh
if [ $? -ne 0 ]; then
    echo "Build failed"
    exit 1
fi

# Test basic functionality
cat > /tmp/test_kestrel.lua << 'LUA'
local ffi = require("ffi")
local Router = require("02-router/router")

print("\n=== Kestrel v2.0 Smoke Test ===\n")

-- Initialize with 1GB for testing
Router.init(1024 * 1024 * 1024)

-- Load test experts
for i = 1, 4 do
    local data = string.rep(string.char(i), 1024) -- 1KB each
    Router.load_expert(i, data, i <= 2)
end

-- Test routing
local hidden = {0.1, 0.2, 0.3, 0.4, 0.5}
local results = Router.route(hidden)

print("\n✓ Routing successful")
print("  Results from " .. #results .. " experts")

-- Cleanup
Router.deinit()
print("\n=== Test Complete ===")
LUA

luajit /tmp/test_kestrel.lua
if [ $? -ne 0 ]; then
    echo "Test failed"
    exit 1
fi

echo "✓ All tests passed"
