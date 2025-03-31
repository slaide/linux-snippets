#!/usr/bin/env bash

# adapted from https://forum.linuxcnc.org/9-installing-linuxcnc/55048-raspberry-pi-os-preempt-rt-6-13-kernel-cookbook
# this script here does NOT check the signature of the patch file

# another tip from that link is to change the WM protocol from wayland to X11
# (with raspi-config in display settings)
# because x11 has lower latency

mkdir linux-6.14-rt
cd linux-6.14-rt

#git clone -b rpi-6.14.y --depth=1 https://github.com/raspberrypi/linux

sudo apt install bc bison flex libssl-dev make
sudo apt install libncurses5-dev

# change from the post: non-rc patch
curl -OL https://cdn.kernel.org/pub/linux/kernel/projects/rt/6.14/patch-6.14-rt3.patch.gz
gzip -d patch-6.14-rt3.patch.gz

# cd into the repo
cd linux

patch -p1 < ../patch-6.14-rt3.patch

echo "KERNEL=kernel_2712" > .config
make bcm2712_defconfig

# change config manually (see post!)
# not actually run here because RT is enabled without it, and starting an interactive tool from within a script is bad style
# $ make menuconfig

# then manually change one line in .config (slightly adapted from the post for the rpi5, the 16k is for 16k pages):
# from: CONFIG_LOCALVERSION="-v8-16k"
# to:   CONFIG_LOCALVERSION="-v8_full_preempt-16k"
# that is just for display purposes, so not required.

# this takes probably less than the 2h10m for the rpi4 on the more powerful rpi5, but i have not timed it
# also not sure why 6 tasks on 4core machines, but whatever..
make -j6 Image.gz modules dtbs 2>&1 | tee make.log
sudo make -j6 modules_install 2>&1 | tee install.log

sudo cp /boot/firmware/kernel_2712.img /boot/firmware/kernel_2712-backup.img
sudo cp arch/arm64/boot/Image.gz /boot/firmware/kernel_2712.img
sudo cp arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/overlays/
sudo cp arch/arm64/boot/dts/overlays/README /boot/firmware/overlays/

echo "add the kernel=kernel_2712 line /boot/firmware/config.txt (or change if there already is a kernel= line)"

echo "done. reboot to apply."
