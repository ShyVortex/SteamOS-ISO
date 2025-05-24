FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y \
    kpartx          # to map partitions from an img
grub-pc-bin     # for i386-pc grub installation
grub-efi-amd64  # for EFI stub/boot
xorriso         # for hybrid ISO creation
squashfs-tools  # if you want live-fs compression
syslinux-utils  # for MBR boot code

WORKDIR /workspace
COPY steamos-recovery.img .

# Entrypoint script will generate ISO
COPY build-iso.sh /usr/local/bin/build-iso.sh
RUN chmod +x /usr/local/bin/build-iso.sh

ENTRYPOINT ["build-iso.sh"]
