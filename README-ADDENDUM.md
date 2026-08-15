Gullwing README Addendum — The Kestrel Engine
Add to the main README (Key Capabilities / Regulatory sections):
---
🐦 The Kestrel — Embedded Inference
`gullwing ask` now runs on Gullwing's own embedded engine — zero external
processes required. Three tiers, selected automatically:
Tier	Engine	How
1	`kestrel-ffi`	colibrì kernels compiled by Zig, in-process via LuaJIT FFI
0	`kestrel-coli`	colibrì's `coli serve` on loopback (127.0.0.1 only)
—	`ollama`	classic fallback, unchanged
```bash
# Build the engine (WSL2): vendors colibrì (Apache-2.0, LICENSE kept)
./engine/build-kestrel.sh

# Serve Tier 0, then ask:
./engine/vendor/colibri/coli serve &
GULLWING_ENGINE=coli gullwing ask /usr/bin/ls
```
Air-gap verified: every tier is loopback-or-in-process. The Ask-LLM layer is
now part of the attested binary set — one fewer trust surface in the CRA
evidence file. Engine provenance (commit SHA + sha256) is recorded in
`engine/MANIFEST.txt` and ships with the CRA Proof Bundle.
> _The Cormorant dives. The Gullwing watches. The Kestrel carries._
---
Test plan (add to your CI gate alongside the detection matrix)
Fallback: stop all engines except Ollama → `gullwing ask` still answers.
Routing: start `coli serve` → response carries `engine=kestrel-coli`.
Air-gap: block egress → all tiers still serve (loopback by construction).
Regression fixture: the grounded `/usr/bin/ls` verdict (class
`system_utility`, integrity caveat present) is pinned — any engine or
prompt change that breaks grounding fails the gate.
Provenance: `engine/MANIFEST.txt` sha256 matches the shipped binary.
Housekeeping note
`gullwing ask` call sites need one change:
```lua
local engine = require("moabi-engine")
local res, err = engine.ask(layer_evidence_text)
if res then print(res.engine, res.text) else print("ERR", err) end
```
