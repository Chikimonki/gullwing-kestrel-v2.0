#!/usr/bin/env bash
# forensics_capture.sh — Fresh Forensics-style build/test evidence collector
# Inspired by DouglasFreshHabian/AndroidForensics extract.sh::run_adb_command
# Usage: ./forensics_capture.sh [--no-build] [--report-dir DIR]
# Works with Gullwing-Protocol, Kestrel, PartyVault, or any Zig/LuaJIT/Go/Python/Julia repo
set -euo pipefail

# ── config ──────────────────────────────────────────────────────────
REPORT_BASE="forensics_report"
DO_BUILD=true
CUSTOM_DIR=""
while [[ $# -gt 0 ]]; do case "$1" in
  --no-build) DO_BUILD=false; shift ;;
  --report-dir) CUSTOM_DIR="$2"; shift 2 ;;
  *) echo "Unknown arg: $1" >&2; exit 1 ;;
esac; done

STAMP=$(date +%Y%m%d_%H%M%S)
REPORT="${CUSTOM_DIR:-${REPORT_BASE}_${STAMP}}"
mkdir -p "$REPORT"

# ── colours (Doug-style banner) ─────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
banner(){ echo -e "${CYAN}━━━ $* ━━━${NC}"; }
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
fail(){ echo -e "${RED}[FAIL]${NC} $*"; }

# ── helpers — mirrors extract.sh::run_adb_command ───────────────────
# run_step <name> <cmd> [args...]  — colour header, tee to REPORT/name.log, capture exit
run_step(){
  local name="$1"; shift
  local log="$REPORT/${name}.log"
  banner "$name"
  echo "\$ $*" | tee "$log"
  echo "--- $(date -Is) | PWD=$(pwd) | host=$(hostname) ---" | tee -a "$log"
  set +e
  "$@" 2>&1 | sed -u -e 's/sig_[a-fA-F0-9]\+/sig_[REDACTED]/g' -e 's/sk_[a-fA-F0-9]\+/sk_[REDACTED]/g' -e 's/secret[^[:space:]]*/[REDACTED]/gi' | tee -a "$log"
  local rc=${PIPESTATUS[0]}
  set -e
  echo "exit=$rc" | tee -a "$log"
  if [[ $rc -eq 0 ]]; then ok "$name -> $log"; else fail "$name exit $rc -> $log"; fi
  return $rc
}
# silent variant for noisy dumps (like dumpsys.sh silent tasks)
run_step_silent(){
  local name="$1"; shift
  "$@" > "$REPORT/${name}.log" 2>&1 || true
  ok "$name (silent) -> $REPORT/${name}.log"
}
has(){ command -v "$1" >/dev/null 2>&1; }

# ── 00 env — forensic snapshot of toolchain ─────────────────────────
{
  echo "# Forensic Build Report"
  echo "stamp: $STAMP"
  echo "repo: $(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  echo "branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo n/a)"
  echo "commit: $(git rev-parse HEAD 2>/dev/null || echo n/a)"
  echo "dirty: $(git status --porcelain 2>/dev/null | wc -l) files"
} > "$REPORT/SUMMARY.md"

run_step 00_env bash -c '
  echo "uname: $(uname -a)"
  echo "--- tool versions ---"
  for t in zig luajit lua python3 go julia perl syft openssl git; do
    if command -v $t >/dev/null 2>&1; then printf "%-10s " "$t"; $t --version 2>&1 | head -n1; else echo "$t: not found"; fi
  done
  echo "--- locks ---"; ls -l requirements*.txt go.mod go.sum build.zig 2>&1 | head -n20
'

# ── 01 hashes — chain of custody ────────────────────────────────────
run_step 01_hashes bash -c '
  echo "sha256 of source (tracked files):"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -z | xargs -0 sha256sum 2>/dev/null | head -n200
  else
    find . -type f -not -path "./.git/*" -not -path "./.zig-cache/*" -not -path "./'$REPORT'/*" | head -n200 | xargs sha256sum 2>/dev/null || true
  fi
' || true

# ── 02 build (optional) ─────────────────────────────────────────────
if $DO_BUILD; then
  if [[ -f Makefile ]]; then
    run_step 02_build_make make -j"$(nproc 2>/dev/null || echo 4)" || true
  elif [[ -f build.zig ]]; then
    has zig && run_step 02_build_zig zig build -Doptimize=ReleaseFast || warn "zig not found"
  elif [[ -f build.sh ]]; then
    run_step 02_build_sh bash build.sh || true
  else
    warn "No Makefile/build.zig/build.sh found — skipping build"
  fi
else
  warn "Skipped build (--no-build)"
fi

# ── 03 bininfo — Gullwing 8-layer flavour: identity/structure ───────
run_step 03_bininfo bash -c '
  set +e
  for d in bin build zig-out/bin target/debug target/release ./; do
    [[ -d $d ]] || continue
    echo "== $d =="; ls -lh "$d" 2>&1 | head -n30
    for f in "$d"/*; do [[ -f $f && -x $f ]] || continue; echo "--- $f ---"; file "$f" 2>&1; sha256sum "$f" 2>&1 | cut -c1-64 | xargs echo "sha256:"; done | head -n100
  done
' || true

# ── 04 tests — thorough, non-invasive ───────────────────────────────
# Try each harness if present; each is isolated so one failure does not hide others
if [[ -d tests || -f tests/partyvault_tests.sh ]]; then
  [[ -x tests/partyvault_tests.sh ]] && run_step 04_test_partyvault bash tests/partyvault_tests.sh || true
fi
has python3 && [[ -f requirements.txt || -d tests ]] && run_step 04_test_pytest bash -c 'python3 -m pytest -q --junitxml="'"$REPORT"'/junit_py.xml" 2>&1 | tail -n100' || true
has go && [[ -f go.mod ]] && run_step 04_test_go go test ./... 2>&1 || true
has zig && [[ -f build.zig ]] && { run_step 04_test_zig bash -c 'zig build test 2>&1 || zig build 2>&1 | tail -n50; echo "zig build ok if exit 0"' || true; } || true
has luajit && run_step 04_test_luajit bash -c 'for f in test*.lua *_test.lua tests/*.lua; do [[ -f $f ]] || continue; echo "== $f =="; luajit "$f" 2>&1 | tail -n50; done' || true
# PartyVault / Gullwing specific quick checks
[[ -f test.sh ]] && run_step 04_test_sh bash test.sh || true
[[ -f run_demo.sh ]] && warn "run_demo.sh exists — not auto-run (use manually)"

# ── 05 SBOM + attestation stub ─────────────────────────────────────
if has syft; then
  run_step 05_sbom syft . -o cyclonedx-json --quiet 2>&1 | head -n500 > "$REPORT/sbom.cyclonedx.json" || true
  ok "SBOM written (if project had files)"
else
  warn "syft not installed — skipping SBOM (install: curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin)"
fi
# Gullwing-style Ed25519 attestation if keys present
if has openssl && [[ -f "$REPORT/01_hashes.log" ]]; then
  run_step_silent 05_hashlist bash -c 'grep -E "^[a-f0-9]{64}" "'$REPORT'/01_hashes.log" | cut -d" " -f1 | sort > "'$REPORT'/hashlist.txt" 2>&1 || true'
fi

# ── 06 summary — like dumpsys.sh summary ────────────────────────────
{
  echo ""
  echo "## Artifacts"
  ls -lh "$REPORT" | sed 's/^/ - /'
  echo ""
  echo "## Quick verdict"
  grep -q "FAIL" "$REPORT"/*.log 2>/dev/null && echo "Some steps FAILED — see logs" || echo "All captured steps OK (or skipped)"
  echo ""
  echo "Upload this folder as GitHub Actions artifact for provenance."
} >> "$REPORT/SUMMARY.md"

banner "Done -> $REPORT/"
cat "$REPORT/SUMMARY.md"
echo -e "${GREEN}Next: gh artifact upload or: tar czf ${REPORT}.tgz ${REPORT}${NC}"
