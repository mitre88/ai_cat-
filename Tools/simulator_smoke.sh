#!/bin/bash
# Boots an iPhone simulator, installs the built app and launches it with `-AICatSmoke`: the app skips
# onboarding, opens the map, and prints `AICAT_SMOKE: … frames=60 OK` once the 3D home world has rendered with
# its textures and sky, then exits 0. Fails if that line never appears (crash, hang, RealityKit failure).
# Usage: Tools/simulator_smoke.sh <path/to/AICat.app> [seconds]   (CI builds with -derivedDataPath /tmp/aicat-dd)
set -uo pipefail
APP=${1:?path to AICat.app}
WAIT=${2:-120}
LOG=/tmp/aicat-smoke-launch.log
BUNDLE=com.mitre.aicat

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    if "iOS" not in runtime: continue
    for d in devices:
        if d.get("isAvailable") and "iPhone" in d["name"] and "Pro" not in d["name"] and "Max" not in d["name"]:
            key = (runtime, d["name"])
            if best is None or key > best[0]: best = (key, d["udid"])
print(best[1] if best else "")')
if [ -z "$UDID" ]; then echo "no available iPhone simulator"; xcrun simctl list devices available | head -20; exit 1; fi
echo "simulator: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP"
: > "$LOG"
xcrun simctl launch --console-pty "$UDID" "$BUNDLE" -AICatSmoke > "$LOG" 2>&1 &
PID=$!
for _ in $(seq 1 "$WAIT"); do
  grep -q "AICAT_SMOKE: frames=" "$LOG" && break
  kill -0 "$PID" 2>/dev/null || break
  sleep 1
done
kill "$PID" 2>/dev/null || true
echo "=== app output (smoke lines, errors) ==="
grep -E "AICAT_SMOKE|error|Error|crash|Fatal|Terminating|exception" "$LOG" | head -40
if grep -q "AICAT_SMOKE: frames=.* OK" "$LOG"; then echo "=== SIMULATOR SMOKE OK ==="; exit 0; fi
echo "=== SIMULATOR SMOKE FAILED (full log: $LOG) ==="; tail -40 "$LOG"; exit 1
