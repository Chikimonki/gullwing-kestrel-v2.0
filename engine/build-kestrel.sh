#!/usr/bin/env bash
# ============================================================================
# KESTREL BUILD — vendors and builds Gullwing's embedded inference engine
# Target: WSL2 Ubuntu 24.04 (also works on native Linux)
#
# Tier 0: builds colibrì's official `coli` engine (guaranteed-correct)
# Tier 1: (optional, needs zig) compiles the kestrel bridge stub
#
# Attribution: colibrì (c) Vincenzo Fornaro, Apache-2.0. LICENSE vendored.
# ============================================================================
set -euo pipefail

KESTREL_DIR=$(cd "$(dirname "$0")" && pwd)
VENDOR_DIR="$KESTREL_DIR/vendor/colibri"
WASTE_VENDOR_DIR="$KESTREL_DIR/vendor/waste"
COLIBRI_REPO="${COLIBRI_REPO:-https://github.com/JustVugg/colibri.git}"
WASTE_REPO="${WASTE_REPO:-https://github.com/sqliteai/waste.git}"
MODEL_DIR="${GULLWING_MODELS:-/mnt/d/models}"

echo "=== Kestrel build ==="

# --- 0. Toolchain checks -----------------------------------------------------
command -v gcc >/dev/null || { echo "[FAIL] gcc not found"; exit 1; }
command -v git >/dev/null || { echo "[FAIL] git not found"; exit 1; }
HAVE_ZIG=0
if command -v zig >/dev/null; then HAVE_ZIG=1; echo "[ok] zig $(zig version)"; 
else echo "[note] zig absent — Tier 1 bridge build will be skipped"; fi

# --- 1. Vendor colibrì (shallow clone, license preserved) ---------------------
if [ ! -d "$VENDOR_DIR/.git" ]; then
    echo "[..] cloning colibrì (shallow)..."
    git clone --depth 1 "$COLIBRI_REPO" "$VENDOR_DIR"
else
    echo "[ok] colibrì already vendored"
fi
COLIBRI_SHA=$(git -C "$VENDOR_DIR" rev-parse HEAD)
[ -f "$VENDOR_DIR/LICENSE" ] || { echo "[FAIL] upstream LICENSE missing — aborting (Apache-2.0 attribution required)"; exit 1; }

# --- 2. Tier 0: build the official engine ------------------------------------
echo "[..] building coli engine..."
if [ -x "$VENDOR_DIR/setup.sh" ]; then
    (cd "$VENDOR_DIR" && ./setup.sh)
elif [ -f "$VENDOR_DIR/Makefile" ]; then
    make -C "$VENDOR_DIR" glm
else
    echo "[FAIL] no setup.sh or Makefile in vendored colibrì"; exit 1
fi

COLI_BIN=$(find "$VENDOR_DIR" -maxdepth 2 -name coli -type f -executable | head -1 || true)
[ -n "$COLI_BIN" ] || COLI_BIN="$VENDOR_DIR/glm"
[ -x "$COLI_BIN" ] || { echo "[FAIL] engine binary not produced"; exit 1; }
echo "[ok] engine binary: $COLI_BIN"

# Ground-truth habit: what is this binary actually linked against?
echo "--- readelf ground truth (expect: zero or libc-only) ---"
readelf -d "$COLI_BIN" 2>/dev/null | grep NEEDED || echo "(statically linked — no NEEDED entries)"

# --- 3. Validate against the model directory, if present ----------------------
if [ -d "$MODEL_DIR" ]; then
    echo "[..] running coli doctor against $MODEL_DIR"
    (cd "$(dirname "$COLI_BIN")" && ./coli doctor "$MODEL_DIR" || true)
else
    echo "[note] $MODEL_DIR not found — doctor skipped."
    echo "       Put model weights on D: and re-run to validate placement budget."
fi

# --- 4. Tier 1: bridge stub (needs zig) ---------------------------------------
if [ "$HAVE_ZIG" = "1" ] && [ -f "$KESTREL_DIR/kestrel_bridge.c" ]; then
    echo "[..] compiling kestrel bridge stub with zig cc"
    zig cc -O2 -shared -fPIC "$KESTREL_DIR/kestrel_bridge.c" \
        -o "$KESTREL_DIR/libkestrel.so"
    echo "[ok] libkestrel.so built (stub mode — see ADAPT blocks)"
else
    echo "[note] Tier 1 bridge build skipped"
fi

# --- 4b. Vendor WASTE (Revision 2: embeddable-C streaming backend) -------------
WASTE_SHA="(not vendored)"
if git clone --depth 1 "$WASTE_REPO" "$WASTE_VENDOR_DIR" 2>/dev/null || [ -d "$WASTE_VENDOR_DIR/.git" ]; then
    WASTE_SHA=$(git -C "$WASTE_VENDOR_DIR" rev-parse HEAD)
    [ -f "$WASTE_VENDOR_DIR/LICENSE" ] || echo "[warn] WASTE LICENSE file not found — check attribution before shipping"
    echo "[ok] WASTE vendored — embeddable C API target for Tier 1"
else
    echo "[note] WASTE vendoring skipped (clone failed — offline?)"
fi

# --- 5. Manifest (for the evidence bundle) ------------------------------------
{
    echo "kestrel-manifest v2"
    echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "colibri-repo: $COLIBRI_REPO"
    echo "colibri-commit: $COLIBRI_SHA"
    echo "colibri-license: Apache-2.0 (LICENSE vendored)"
    echo "waste-repo: $WASTE_REPO"
    echo "waste-commit: $WASTE_SHA"
    echo "waste-license: Apache-2.0 (check LICENSE vendored)"
    echo "engine-binary: $COLI_BIN"
    echo "engine-sha256: $(sha256sum "$COLI_BIN" | awk '{print $1}')"
    echo "model-dir: $MODEL_DIR"
    echo "tabfm: EVALUATED-NOT-ADOPTED (weights non-commercial) — see design doc §8.2"
} > "$KESTREL_DIR/MANIFEST.txt"
echo "[ok] manifest written: $KESTREL_DIR/MANIFEST.txt"

echo
echo "=== Kestrel build complete ==="
echo "Start Tier 0 serving (loopback only):  $COLI_BIN serve"
echo "Then:  GULLWING_ENGINE=coli gullwing ask /usr/bin/ls"
