#!/usr/bin/env bash
set -euo pipefail
IMG=steamos-recovery.img
WORK=/workspace
MNT=/mnt/loop
ISO_OUT=steamos-recovery.iso

# 1) Map partitions
kpartx -av "$IMG"
# Suppose this creates /dev/loop0p1 (EFI), /dev/loop0p2 (rootfs), etc.

# 2) Mount partitions
mkdir -p $MNT/efi $MNT/root
mount /dev/mapper/loop0p2 $MNT/root
mount /dev/mapper/loop0p1 $MNT/efi

# 3) Prepare ISO tree
ISO_TREE=$WORK/iso-tree
rm -rf $ISO_TREE
mkdir -p $ISO_TREE/{EFI,boot,live}

# 4) Copy files into the tree
cp -r $MNT/root/*   $ISO_TREE/live/
cp -r $MNT/efi/*    $ISO_TREE/EFI/
# (You may need to reorganize into /EFI/boot/, add grub.cfg, etc.)

# 5) Generate grub.cfg
cat > $ISO_TREE/EFI/boot/grub.cfg <<EOF
set timeout=5
menuentry "SteamOS Recovery" {
  linux /boot/vmlinuz root=UUID=$(blkid -s UUID -o value /dev/mapper/loop0p2) ro
  initrd /boot/initrd.img
}
EOF

# 6) Create hybrid ISO with both BIOS and UEFI support
xorriso \
  -as mkisofs \
  -iso-level 3 \
  -o $ISO_OUT \
  -full-iso9660-filenames \
  -volid "STEAMOS_RECOVERY" \
  -eltorito-alt-boot \
    -e EFI/boot/bootx64.efi \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
  -eltorito-boot boot/syslinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
  $ISO_TREE

# 7) Clean up
umount $MNT/efi $MNT/root
kpartx -d "$IMG"
