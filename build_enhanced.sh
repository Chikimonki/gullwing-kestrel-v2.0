#!/bin/bash

echo "=== Building Kestrel v2.0 Enhanced ==="

# Build ring buffer tests
echo "Testing ring buffer..."
zig test 04-streaming/ring_buffer.zig

# Build enhanced bridge
echo "Building enhanced bridge..."
zig build-lib \
    03-ffi-bridge/bridge_enhanced.zig \
    -dynamic \
    -O ReleaseFast \
    -lc \
    -femit-bin=libkestrel_enhanced.so

if [ $? -eq 0 ] && [ -f "libkestrel_enhanced.so" ]; then
    echo "✓ libkestrel_enhanced.so built successfully"
    ls -la libkestrel_enhanced.so
    echo ""
    echo "Exported symbols:"
    nm -D libkestrel_enhanced.so | grep kestrel
else
    echo "✗ Build failed"
    exit 1
fi
