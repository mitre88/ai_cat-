#!/bin/bash
# Fetch a Swift toolchain on Linux without swift.org access: pull the official swift:6.1-noble image
# layers from Google's public Docker Hub mirror and unpack them into $1 (default: ./.swift-toolchain).
# Afterwards: export PATH="$1/usr/bin:$PATH" && swift --version
set -eu
DEST=${1:-.swift-toolchain}
REG=https://mirror.gcr.io/v2/library/swift
TAG=${SWIFT_IMAGE_TAG:-6.1-noble}
mkdir -p "$DEST/.layers"
cd "$DEST"
curl -sS -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.index.v1+json" "$REG/manifests/$TAG" -o .layers/index.json
DIGEST=$(jq -r '.manifests[] | select(.platform.os=="linux" and .platform.architecture=="amd64") | .digest' .layers/index.json | head -1)
curl -sS -H "Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json" "$REG/manifests/$DIGEST" -o .layers/manifest.json
i=0
jq -r '.layers[] | "\(.digest) \(.size)"' .layers/manifest.json | while read -r digest size; do
  i=$((i+1))
  echo "layer $i ($size bytes)"
  curl -sS -L "$REG/blobs/$digest" -o ".layers/layer-$i.tar.gz"
  tar -xzf ".layers/layer-$i.tar.gz" --overwrite 2>/dev/null || true
done
echo "toolchain ready: $(pwd)/usr/bin/swift"
