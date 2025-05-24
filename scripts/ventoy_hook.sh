#!/usr/bin/env bash
set -euo pipefail

IMG=/work/recovery.img
ROOT=/work/mnt-root

# 1) Map partitions
kpartx -av "$IMG"

# 2) Find and mount the recovery root filesystem partition
TMPDIR=/work/tmp-mnt
mkdir -p "$TMPDIR"
ROOT=""
for part in /dev/mapper/loop?p*; do
  if mount "$part" "$TMPDIR" 2>/dev/null; then
    if [ -d "$TMPDIR/etc/initcpio" ]; then
      ROOT="$TMPDIR"
      break
    else
      umount "$TMPDIR"
    fi
  fi
done

if [ -z "$ROOT" ]; then
  echo "Error: could not find root filesystem partition containing /etc/initcpio"
  exit 1
fi

# 3) Install mkinitcpio hooks
mkdir -p "$ROOT/etc/initcpio/{install,hooks}"

cat > "$ROOT/etc/initcpio/install/steamimg" << 'HOOK'
#!/usr/bin/env bash
build() {
  add_module loop
  add_runscript
}
help() {
  cat <<H
Support for mounting SteamOS recovery from Ventoy.
Syntax: steamimg=<part>@<path>
H
}
HOOK
chmod +x "$ROOT/etc/initcpio/install/steamimg"

cat > "$ROOT/etc/initcpio/hooks/steamimg" << 'HOOK'
#!/usr/bin/env bash
run_hook() {
  case $steamimg in
    *@*)
      imgpart=${steamimg%%@*}
      imgpath=${steamimg#*@}
      poll_device "$imgpart"
      mkdir /imgpart_root
      mount "$imgpart" /imgpart_root
      losetup -Pf /imgpart_root"$imgpath" || err "losetup failed"
    ;;
  esac
}
HOOK
chmod +x "$ROOT/etc/initcpio/hooks/steamimg"

# 4) Inject into mkinitcpio.conf
sed -i '/^HOOKS=/ s/)/ steamimg)/' "$ROOT/etc/mkinitcpio.conf"

# 5) Bind‐mount and rebuild
mount --bind /dev "$ROOT/dev"
mount --bind /sys "$ROOT/sys"
mount --bind /proc "$ROOT/proc"

chroot "$ROOT" mkinitcpio -P

# 6) Cleanup
umount "$ROOT"/{dev,sys,proc}
umount "$ROOT"
kpartx -d "$IMG"
