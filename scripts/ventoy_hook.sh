#!/usr/bin/env bash
set -euo pipefail

IMG="/work/steamos-recovery.img"
MOUNTDIR="/work/rootfs"
MODROOT="/work/tmp-mnt"

echo "==> Setting up loop device..."
LOOPDEV=$(losetup --show -Pf "$IMG")

echo "==> Mapping partitions via kpartx..."
kpartx -av "$LOOPDEV"

# Derive the mapper path for the root fs (here partition 3)
BASENAME=$(basename "$LOOPDEV")
PARTROOT="/dev/mapper/${BASENAME}p3"

echo "==> Creating mount points..."
mkdir -p "$MOUNTDIR" "$MODROOT"

echo "==> Mounting root filesystem from $PARTROOT..."
mount "$PARTROOT" "$MOUNTDIR"

echo "==> Copying root filesystem for modification (without xattrs)…"
rsync -a --no-xattrs "$MOUNTDIR/" "$MODROOT/"

echo "==> Removing SteamOS mkinitcpio drop-ins…"
rm -f "$MODROOT/etc/initcpio.d"/20-steamdeck.conf

echo "==> Ensuring /bin/bash exists…"
mkdir -p "$MODROOT/bin"
ln -sf /usr/bin/bash "$MODROOT/bin/bash"

echo "==> Injecting Ventoy compatibility hook…"
mkdir -p "$MODROOT/etc/initcpio/install" "$MODROOT/etc/initcpio/hooks"
cp /work/scripts/steamimg      "$MODROOT/etc/initcpio/install/steamimg"
cp /work/scripts/steamimg.hook "$MODROOT/etc/initcpio/hooks/steamimg"
chmod +x "$MODROOT/etc/initcpio/install/steamimg" \
         "$MODROOT/etc/initcpio/hooks/steamimg"

echo "==> Overriding HOOKS in mkinitcpio.conf…"
# Replace entire HOOKS line so no unwanted hooks slip in
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block steamimg filesystems keyboard fsck)/' \
    "$MODROOT/etc/mkinitcpio.conf"

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

for preset_path in "${PRESETS[@]}"; do
  preset_name=$(basename "$preset_path" .preset)
  echo "→ Rebuilding initramfs for preset '$preset_name'…"
  arch-chroot "$MODROOT" mkinitcpio -p "$preset_name"
done

echo "==> Cleaning up…"
umount "$MODROOT"/{dev,sys,proc}
umount "$MOUNTDIR"
kpartx -d "$LOOPDEV"
losetup -d "$LOOPDEV"

echo "✅ ventoy_hook.sh completed successfully."
