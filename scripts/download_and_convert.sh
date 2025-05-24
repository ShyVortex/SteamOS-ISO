#!/usr/bin/env bash
set -euo pipefail

echo "Downloading latest Steam Deck recovery image..."
curl -sSL "https://steamdeck-images.steamos.cloud/recovery/steamdeck-repair-latest.img.bz2" \
    -o recovery.img.bz2
bunzip2 recovery.img.bz2
mv recovery.img recovery.raw

# Convert raw image to ISO
xorriso -indev recovery.raw -outdev recovery.iso

echo "Created recovery.iso"
