#!/bin/bash
# One-command check on a Mac: package tests + simulator build (with and without the iPhone Duo flag).
#   Tools/xcode_smoke.sh            → Xcode 27.1 (AICAT_DUO on, as the project ships)
#   Tools/xcode_smoke.sh --no-duo   → Xcode 26 (strips AICAT_DUO so the iOS 27.1-only files are skipped)
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== AICatCore: swift test ==="
(cd Packages/AICatCore && swift test 2>&1 | tail -5)
echo "=== Xcode: resolve packages ==="
xcodebuild -resolvePackageDependencies -project AICat.xcodeproj -scheme AICat >/dev/null
DEST="generic/platform=iOS Simulator"
if [ "${1:-}" = "--no-duo" ]; then
  echo "=== Xcode: build for simulator (AICAT_DUO off) ==="
  xcodebuild build -project AICat.xcodeproj -scheme AICat -destination "$DEST" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) DEBUG' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
else
  echo "=== Xcode: build for simulator (AICAT_DUO on) ==="
  xcodebuild build -project AICat.xcodeproj -scheme AICat -destination "$DEST" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
fi
echo "=== SMOKE DONE ==="
