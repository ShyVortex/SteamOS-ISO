#!/bin/bash
set -euo pipefail

IMG="/work/steamos-recovery.img"
MOUNTDIR="/work/rootfs"
MODROOT="/work/tmp-mnt"

echo "==> Setting up loop device..."
LOOPDEV=$(losetup --show -Pf "$IMG")

echo "==> Mapping partitions via kpartx..."
kpartx -av "$LOOPDEV"

# derive the mapper path for the root fs (usually the 3rd partition)
BASENAME=$(basename "$LOOPDEV")          # e.g. "loop0"
PARTROOT="/dev/mapper/${BASENAME}p3"     # e.g. "/dev/mapper/loop0p3"

echo "==> Creating mount points..."
mkdir -p "$MOUNTDIR" "$MODROOT"

echo "==> Mounting root filesystem from $PARTROOT..."
mount "$PARTROOT" "$MOUNTDIR"

echo "==> Copying root filesystem for modification..."
rsync -a --no-xattrs "$MOUNTDIR/" "$MODROOT/"

echo "==> Injecting Ventoy compatibility hook..."
mkdir -p "$MODROOT/etc/initcpio/install"
mkdir -p "$MODROOT/etc/initcpio/hooks"

cp /work/scripts/steamimg "$MODROOT/etc/initcpio/install/"
cp /work/scripts/steamimg.hook "$MODROOT/etc/initcpio/hooks/"
chmod +x "$MODROOT/etc/initcpio/install/steamimg"

echo "==> Patching mkinitcpio.conf HOOKS..."
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block steamimg filesystems keyboard fsck)/' "$MODROOT/etc/mkinitcpio.conf"

echo "==> Binding /dev, /sys, /proc for chroot..."
mount --bind /dev  "$MODROOT/dev"
mount --bind /sys  "$MODROOT/sys"
mount --bind /proc "$MODROOT/proc"

echo "==> Detecting available initramfs presets..."
PRESETS=( "$MODROOT/etc/initcpio.d/"*.preset )
if [ ${#PRESETS[@]} -eq 0 ]; then
  echo "❌ No mkinitcpio presets found; cannot rebuild initramfs."
  exit 1
fi

for preset_path in "${PRESETS[@]}"; do
  preset_name=$(basename "$preset_path" .preset)
  echo "→ Rebuilding initramfs for preset '$preset_name'"
  arch-chroot "$MODROOT" mkinitcpio -p "$preset_name"
done

echo "==> Cleaning up..."
umount "$MODROOT/dev"
umount "$MODROOT/sys"
umount "$MODROOT/proc"
umount "$MOUNTDIR"
kpartx -d "$LOOPDEV"
losetup -d "$LOOPDEV"
