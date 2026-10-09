#!/bin/bash
# One-command check on a Mac: package tests + simulator build (with and without the iPhone Duo flag).
#   Tools/xcode_smoke.sh            → Xcode 27.1 (AICAT_DUO on, as the project ships)
#   Tools/xcode_smoke.sh --no-duo   → Xcode 26 (strips AICAT_DUO so the iOS 27.1-only files are skipped)
# Full logs land in /tmp/aicat-smoke/. The script keeps going after a failure and prints every distinct
# compiler error, so one run shows everything there is to fix (paste the output in the chat).
set -uo pipefail
cd "$(dirname "$0")/.."
LOG=/tmp/aicat-smoke
mkdir -p "$LOG"
STATUS=0

echo "=== AICatCore: swift test ==="
(cd Packages/AICatCore && swift test > "$LOG/swift-test.log" 2>&1)
TEST=$?
grep -E "error:|failed|Executed" "$LOG/swift-test.log" | tail -8
if [ $TEST -ne 0 ]; then echo "package tests FAILED (see $LOG/swift-test.log)"; STATUS=1; fi

echo "=== Xcode: resolve packages ==="
if ! xcodebuild -resolvePackageDependencies -project AICat.xcodeproj -scheme AICat > "$LOG/resolve.log" 2>&1; then
  echo "resolve FAILED (see $LOG/resolve.log)"; tail -5 "$LOG/resolve.log"; STATUS=1
fi

DEST="generic/platform=iOS Simulator"
if [ "${1:-}" = "--no-duo" ]; then
  echo "=== Xcode: build for simulator (AICAT_DUO off) ==="
  xcodebuild build -project AICat.xcodeproj -scheme AICat -destination "$DEST" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' CODE_SIGNING_ALLOWED=NO > "$LOG/xcodebuild.log" 2>&1
else
  echo "=== Xcode: build for simulator (AICAT_DUO on) ==="
  xcodebuild build -project AICat.xcodeproj -scheme AICat -destination "$DEST" CODE_SIGNING_ALLOWED=NO > "$LOG/xcodebuild.log" 2>&1
fi
BUILD=$?
# every distinct error with its file:line (paths relative to the repo), then the verdict
grep -E "error:" "$LOG/xcodebuild.log" | sed -E 's#^.*/(AICat/|Packages/|Config/)#\1#' | sort -u | head -80
grep -E "\*\* BUILD (SUCCEEDED|FAILED) \*\*" "$LOG/xcodebuild.log" | tail -1
if [ $BUILD -ne 0 ]; then STATUS=1; fi

if [ $STATUS -eq 0 ]; then echo "=== SMOKE OK (logs in $LOG) ==="; else echo "=== SMOKE FAILED (logs in $LOG) ==="; fi
exit $STATUS
