#!/bin/bash

echo "=== Building Kestrel v2.0 ==="

# Clean previous build
rm -f libkestrel.so
rm -rf zig-out .zig-cache

# Simple build command
echo "Building Zig shared library..."
zig build-lib 03-ffi-bridge/bridge.zig -dynamic -lc -femit-bin=libkestrel.so

# Check result
if [ $? -eq 0 ] && [ -f "libkestrel.so" ]; then
    echo "✓ libkestrel.so built successfully"
    ls -la libkestrel.so
    file libkestrel.so
    echo ""
    echo "Exported symbols:"
    nm -D libkestrel.so | grep kestrel
    echo ""
    echo "=== Build Complete ==="
else
    echo "✗ Build failed"
    exit 1
fi
