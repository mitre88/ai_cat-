#!/bin/bash
# Everything that can be verified on Linux (no iOS SDK):
#   1. AICatCore builds and its tests pass
#   2. every app source file parses (syntax)
#   3. the Foundation-only app files type-check against AICatCore
# Usage: Tools/verify_linux.sh [path-to-toolchain-dir]   (see Tools/linux_toolchain.sh)
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TC=${1:-$ROOT/.swift-toolchain}/usr/bin
[ -x "$TC/swift" ] || TC=$(dirname "$(command -v swift)")
BUILD=${SWIFT_SCRATCH:-/tmp/aicat-core-build}
echo "=== toolchain ===" && "$TC/swift" --version | head -2
echo "=== AICatCore build + test ==="
cd "$ROOT/Packages/AICatCore" && "$TC/swift" build --scratch-path "$BUILD" 2>&1 | tail -3 && "$TC/swift" test --scratch-path "$BUILD" 2>&1 | grep -E "Executed|error|failed" | tail -5
echo "=== app syntax (swiftc -parse) ==="
cd "$ROOT"
fail=0
while IFS= read -r f; do
  "$TC/swiftc" -parse -D AICAT_DUO -D DEBUG "$f" 2>/tmp/aicat-parse.err || { fail=$((fail+1)); echo "PARSE ERROR: $f"; head -20 /tmp/aicat-parse.err; }
done < <(find AICat -name "*.swift" | sort)
echo "parse failures: $fail"
echo "=== typecheck Foundation-only app files ==="
MODDIR=$(find "$BUILD" -name "AICatCore.swiftmodule" -maxdepth 4 | head -1)
"$TC/swiftc" -typecheck -swift-version 5 -D AICAT_DUO -I "$(dirname "$MODDIR")" -module-name AICatApp \
  AICat/App/L10n.swift AICat/Intelligence/CatBrain.swift AICat/Intelligence/ScriptedBrain.swift \
  AICat/Intelligence/KidSafeFilter.swift AICat/Intelligence/FoundationModelsBrain.swift AICat/Intelligence/BrainRouter.swift \
  AICat/Persistence/ProgressStore.swift && echo "typecheck ok"
