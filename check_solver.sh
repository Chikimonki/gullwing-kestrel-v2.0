#!/bin/bash

# Check various locations for wsolve
if [ -f "/mnt/d/moabi/wsolver/wsolve" ]; then
    echo "FOUND:/mnt/d/moabi/wsolver/wsolve"
elif [ -f "/mnt/d/moabi/wsolver/bin/wsolve" ]; then
    echo "FOUND:/mnt/d/moabi/wsolver/bin/wsolve"
elif [ -f "/mnt/d/moabi/wsolver/build/wsolve" ]; then
    echo "FOUND:/mnt/d/moabi/wsolver/build/wsolve"
elif command -v wsolve &> /dev/null; then
    echo "FOUND:$(which wsolve)"
elif docker images | grep -q wsolver; then
    echo "DOCKER:wsolver"
else
    # Check if it needs to be built
    cd /mnt/d/moabi/wsolver
    if make -q 2>/dev/null; then
        echo "BUILT:$(pwd)/wsolve"
    else
        echo "NOT_FOUND"
    fi
fi
