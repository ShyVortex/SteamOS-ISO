#!/bin/bash
set -euo pipefail

IMG="/work/steamos-recovery.img"
TMPDIR="/work/tmp"
MODROOT="/work/rootfs"

mkdir -p "$TMPDIR" "$MODROOT"

# Setup loop device and map partitions
LOOPDEV=$(losetup --find --show "$IMG")
kpartx -av "$LOOPDEV"

sleep 2  # let device settle

# Find partition with /etc/initcpio
for part in /dev/mapper/$(basename "$LOOPDEV")p*; do
  mount "$part" "$TMPDIR" || continue
  if [ -d "$TMPDIR/etc/initcpio" ]; then
    echo "Found rootfs on $part"
    cp -a "$TMPDIR/." "$MODROOT"
    umount "$TMPDIR"
    break
  fi
  umount "$TMPDIR"
done

if [ ! -d "$MODROOT/etc/initcpio" ]; then
  echo "Error: Could not locate Arch rootfs with /etc/initcpio"
  exit 1
fi

# Inject hook
mkdir -p "$MODROOT/etc/initcpio/{install,hooks}"
cp /work/scripts/steamimg "$MODROOT/etc/initcpio/install/"
cp /work/scripts/steamimg.hook "$MODROOT/etc/initcpio/hooks/"

arch-chroot "$MODROOT" mkinitcpio -p linux

# Cleanup
kpartx -dv "$LOOPDEV"
losetup -d "$LOOPDEV"
