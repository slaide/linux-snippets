#!/usr/bin/env bash

set -e

# adapted from https://forum.linuxcnc.org/9-installing-linuxcnc/55048-raspberry-pi-os-preempt-rt-6-13-kernel-cookbook
# this script here does NOT check the signature of the patch file

# another tip from that link is to change the WM protocol from wayland to X11
# (with raspi-config in display settings)
# because x11 has lower latency

mkdir linux-6.15-rt
cd linux-6.15-rt

git clone -b rpi-6.15.y --depth=1 https://github.com/raspberrypi/linux

sudo apt install bc bison flex libssl-dev make libncurses5-dev

# change from the post: non-rc patch (pick latest available version)
# use /older/ to ensure the version here is always fetchable (the 6.y/patch*.gz path only allows the latest, which may change)
curl -OL https://cdn.kernel.org/pub/linux/kernel/projects/rt/6.15/older/patch-6.15-rt2.patch.gz
gzip -d patch-6.15-rt2.patch.gz

# cd into the repo
cd linux

patch -p1 < ../patch-6.15-rt2.patch

make bcm2712_defconfig

# change config manually (see post!)
# not actually run here because RT is enabled without it, and starting an interactive tool from within a script is bad style
# $ make menuconfig

# automatically apply some changes (instead of interactive menuconfig)
./scripts/config --disable PREEMPT
./scripts/config --enable CPU_FREQ_DEFAULT_GOV_PERFORMANCE
./scripts/config --enable PREEMPT_RT
./scripts/config --enable CONFIG_VC4
./scripts/config --enable CONFIG_V3D

# --disable removes the entry, but this specifically requires =n, hence different method to change option
sed -i 's/EFI_DISABLE_RUNTIME=.*/EFI_DISABLE_RUNTIME=n/' .config

# apply changes
make olddefconfig

# optionally: manually change one line in .config (slightly adapted from the post for the rpi5, the 16k is for 16k pages):
# from: CONFIG_LOCALVERSION="-v8-16k"
# to:   CONFIG_LOCALVERSION="-v8_full_preempt-16k"
# that is just for display purposes, so not required.

# this takes probably less than the 2h10m for the rpi4 on the more powerful rpi5, but i have not timed it
# also not sure why 6 tasks on 4core machines, but whatever..
time make prepare
time make CFLAGS="-O3 -march=native" -j6 Image.gz modules dtbs 2>&1 | tee make.log
time sudo make -j6 modules_install 2>&1 | tee install.log

sudo cp /boot/firmware/kernel_2712.img /boot/firmware/kernel_2712-backup.img
sudo cp arch/arm64/boot/Image.gz /boot/firmware/kernel_2712.img
sudo cp arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
sudo cp arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/

echo "add the kernel=kernel_2712 line /boot/firmware/config.txt (or change if there already is a kernel= line)"

echo "done. reboot to apply. after reboot, run \`\$ sudo SKIP_KERNEL=1 PRUNE_MODULES=1 rpi-update rpi-6.15.y\` to update the firmware "
