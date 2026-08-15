#!/bin/bash
# Benchmark colibri baseline on current hardware

echo "=== Colibri Baseline Benchmark ==="
echo "Date: $(date)"
echo ""

# System info
echo "--- System ---"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "C: drive: $(df -h /mnt/c | tail -1 | awk '{print $4}') free"
echo "D: drive: $(df -h /mnt/d | tail -1 | awk '{print $4}') free"
echo ""

# Check colibri binary
COLI_BIN="/mnt/d/moabi/gullwing-kestrel/engine/vendor/colibri/c/colibri"
if [ -f "$COLI_BIN" ]; then
    echo "--- Colibri Binary ---"
    ls -la "$COLI_BIN"
    file "$COLI_BIN"
    echo ""
    
    # Run colibri help
    echo "--- Colibri Help ---"
    "$COLI_BIN" --help 2>&1 | head -30
    echo ""
    
    # Check if colibri has a doctor/plan command
    echo "--- Colibri Doctor ---"
    "$COLI_BIN" doctor 2>&1 | head -20
    echo ""
    
    # Check available models
    echo "--- Colibri Models ---"
    "$COLI_BIN" list 2>&1 | head -20
else
    echo "Colibri binary not found at $COLI_BIN"
    echo "Checking for coli binary..."
    COLI_BIN="/mnt/d/moabi/gullwing-kestrel/engine/vendor/colibri/c/coli"
    if [ -f "$COLI_BIN" ]; then
        ls -la "$COLI_BIN"
        "$COLI_BIN" --help 2>&1 | head -30
    fi
fi

echo ""
echo "=== Benchmark Complete ==="
