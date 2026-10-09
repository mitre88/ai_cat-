#!/bin/bash
# Gate before every commit: project validators + the full Linux verification. Exit 1 on any failure.
#   Tools/precommit.sh [path-to-toolchain-dir]
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
python3 Tools/validate_project.py || { echo "PRECOMMIT FAILED: validator"; exit 1; }
Tools/verify_linux.sh "${1:-}" || { echo "PRECOMMIT FAILED: verify"; exit 1; }
echo "PRECOMMIT OK"
