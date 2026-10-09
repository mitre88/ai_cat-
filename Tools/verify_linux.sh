#!/bin/bash
# Everything that can be verified on Linux (no iOS SDK):
#   1. AICatCore builds and its tests pass
#   2. every app source file parses (syntax)
#   3. the Foundation-only app files type-check against AICatCore
#   4. the whole app type-checks against the shadow frameworks in Tools/shadows
# Usage: Tools/verify_linux.sh [path-to-toolchain-dir]   (see Tools/linux_toolchain.sh)
# Exit code: 0 only when every step passes (CI relies on this).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TC=${1:-$ROOT/.swift-toolchain}/usr/bin
[ -x "$TC/swift" ] || TC=$(dirname "$(command -v swift)")
BUILD=${SWIFT_SCRATCH:-/tmp/aicat-core-build}
STATUS=0

echo "=== toolchain ===" && "$TC/swift" --version | head -2

echo "=== AICatCore build + test ==="
cd "$ROOT/Packages/AICatCore" || exit 1
"$TC/swift" build --scratch-path "$BUILD" 2>&1 | tail -3
TEST_OUT=$("$TC/swift" test --scratch-path "$BUILD" 2>&1)
TEST_STATUS=$?
echo "$TEST_OUT" | grep -E "Executed|error:|failed" | tail -5
if [ $TEST_STATUS -ne 0 ]; then echo "package tests FAILED"; STATUS=1; fi

echo "=== app syntax (swiftc -parse) ==="
cd "$ROOT" || exit 1
fail=0
while IFS= read -r f; do
  "$TC/swiftc" -parse -D AICAT_DUO -D DEBUG "$f" 2>/tmp/aicat-parse.err || { fail=$((fail+1)); echo "PARSE ERROR: $f"; head -20 /tmp/aicat-parse.err; }
done < <(find AICat -name "*.swift" | sort)
echo "parse failures: $fail"
[ "$fail" -eq 0 ] || STATUS=1

echo "=== typecheck Foundation-only app files ==="
MODDIR=$(find "$BUILD" -name "AICatCore.swiftmodule" -maxdepth 4 | head -1)
if "$TC/swiftc" -typecheck -swift-version 5 -D AICAT_DUO -I "$(dirname "$MODDIR")" -module-name AICatApp \
  AICat/App/L10n.swift AICat/Intelligence/CatBrain.swift AICat/Intelligence/ScriptedBrain.swift \
  AICat/Intelligence/FoundationModelsBrain.swift AICat/Intelligence/BrainRouter.swift \
  AICat/Persistence/ProgressStore.swift; then echo "typecheck ok"; else echo "typecheck FAILED"; STATUS=1; fi

echo "=== typecheck the whole app against the shadow frameworks (Tools/shadows) ==="
SHADOWS=${SHADOW_BUILD:-$BUILD/shadows}
mkdir -p "$SHADOWS"
for m in simd UIKit SwiftUI RealityKit; do
  "$TC/swiftc" -emit-module -parse-as-library -module-name $m -emit-module-path "$SHADOWS/$m.swiftmodule" -I "$SHADOWS" "Tools/shadows/$m.swift" || { echo "shadow module $m FAILED"; STATUS=1; }
done
APP_FILES=$(find AICat -name "*.swift" | grep -v "Intelligence/CatVoice.swift" | grep -v "World/SkyEnvironment.swift" | grep -v "Capture/" | sort)
if "$TC/swiftc" -typecheck -swift-version 5 -D AICAT_DUO -D DEBUG -parse-as-library -I "$SHADOWS" -I "$(dirname "$MODDIR")" -module-name AICatApp \
  $APP_FILES Tools/shadows/AppStubs.swift; then echo "shadow typecheck ok"; else echo "shadow typecheck FAILED"; STATUS=1; fi

if [ $STATUS -ne 0 ]; then echo "VERIFY FAILED"; exit 1; fi
echo "VERIFY OK"
