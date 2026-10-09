#!/bin/bash
# Renders every procedural texture and three skies as PNG (macOS). Needs only the Swift toolchain:
# the texture math is plain Foundation code in AICatCore, so this compiles the two files directly.
# Usage: Tools/render_textures.sh [output-dir]   (default /tmp/aicat-textures; opens it in Finder)
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-/tmp/aicat-textures}
BIN=$(mktemp -d)/render_textures
swiftc -O -module-name RenderTextures \
  "$ROOT/Packages/AICatCore/Sources/AICatCore/Textures/ProceduralTextures.swift" \
  "$ROOT/Packages/AICatCore/Sources/AICatCore/Textures/ProceduralSky.swift" \
  "$ROOT/Tools/render_textures/main.swift" -o "$BIN"
"$BIN" "$OUT"
open "$OUT" 2>/dev/null || true
