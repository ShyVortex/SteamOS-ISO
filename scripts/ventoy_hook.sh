#!/usr/bin/env bash
set -euo pipefail

IMG="/work/steamos-recovery.img"
MOUNTDIR="/work/rootfs"
MODROOT="/work/tmp-mnt"

echo "==> Setting up loop device..."
LOOPDEV=$(losetup --show -Pf "$IMG")

echo "==> Mapping partitions via kpartx..."
kpartx -av "$LOOPDEV"

# Derive the mapper path for the root fs (usually partition 3)
BASENAME=$(basename "$LOOPDEV")          # e.g. "loop0"
PARTROOT="/dev/mapper/${BASENAME}p3"     # e.g. "/dev/mapper/loop0p3"

echo "==> Creating mount points..."
mkdir -p "$MOUNTDIR" "$MODROOT"

echo "==> Mounting root filesystem from $PARTROOT..."
mount "$PARTROOT" "$MOUNTDIR"

echo "==> Copying root filesystem for modification (without xattrs)…"
rsync -a --no-xattrs "$MOUNTDIR/" "$MODROOT/"

echo "==> Removing SteamOS mkinitcpio drop-ins…"
rm -f "$MODROOT/etc/initcpio.d"/20-steamdeck.conf
rm -f "$MODROOT/etc/initcpio/conf.d/20-steamdeck.conf"

echo "==> Ensuring /bin/bash exists (relative symlink)…"
mkdir -p "$MODROOT/bin"

# Create a relative link from bin/bash → ../usr/bin/bash
ln -sf ../usr/bin/bash "$MODROOT/bin/bash"

echo "==> Injecting Ventoy compatibility hook…"
mkdir -p "$MODROOT/etc/initcpio/install" "$MODROOT/etc/initcpio/hooks"
cp /work/scripts/steamimg      "$MODROOT/etc/initcpio/install/steamimg"
cp /work/scripts/steamimg.hook "$MODROOT/etc/initcpio/hooks/steamimg"
chmod +x "$MODROOT/etc/initcpio/install/steamimg" \
         "$MODROOT/etc/initcpio/hooks/steamimg"

echo "==> Stripping any remaining SteamDeck drop-ins…"
rm -f "$MODROOT"/etc/initcpio.{d,conf.d}/20-steamdeck.conf \
    "$MODROOT"/usr/{lib,etc}/initcpio.{d,conf.d}/20-steamdeck.conf || true

echo "==> Overriding HOOKS to omit plymouth…"
sed -i 's/\<plymouth\>//g' "$MODROOT/etc/mkinitcpio.conf"
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block steamimg filesystems keyboard fsck)/' "$MODROOT/etc/mkinitcpio.conf"

echo "==> Bind host /usr/bin/env and /usr/bin/bash into chroot…"
# ensure any /usr/bin/env bash shebangs will work
mkdir -p "$MODROOT/usr/bin"
mount --bind /usr/bin/env  "$MODROOT/usr/bin/env"
mount --bind /usr/bin/bash "$MODROOT/usr/bin/bash"

echo "==> Binding /dev, /sys, /proc for chroot…"
mount --bind /dev  "$MODROOT/dev"
mount --bind /sys  "$MODROOT/sys"
mount --bind /proc "$MODROOT/proc"

echo "==> Detecting initramfs presets in /etc/mkinitcpio.d…"
PRESET_DIR="$MODROOT/etc/mkinitcpio.d"
shopt -s nullglob
PRESETS=("$PRESET_DIR"/*.preset)
shopt -u nullglob

if [ ${#PRESETS[@]} -eq 0 ]; then
  echo "❌ No *.preset files found under $PRESET_DIR."
  exit 1
fi

for preset_path in "$MODROOT/etc/mkinitcpio.d/"*.preset; do
  preset_name=$(basename "$preset_path" .preset)
  echo "→ Rebuilding initramfs for '$preset_name' (warnings OK)…"
  arch-chroot "$MODROOT" mkinitcpio -p "$preset_name" || \
    echo "⚠️ mkinitcpio -p $preset_name exited with $?, continuing anyway"
done

echo "==> Un-binding host binaries…"
umount "$MODROOT/usr/bin/env"
umount "$MODROOT/usr/bin/bash"

echo "==> Cleaning up…"
umount "$MODROOT"/{dev,sys,proc}
umount "$MOUNTDIR"
kpartx -d "$LOOPDEV"
losetup -d "$LOOPDEV"

echo "✅ ventoy_hook.sh completed successfully."
