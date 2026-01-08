#!/bin/bash
set -e

KERNEL_VERSION="6.19-rc4"
KERNEL_URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-${KERNEL_VERSION}.tar.gz"
BUILD_DIR="$HOME/linux-${KERNEL_VERSION}"
LOCALVERSION="-rt-custom"

echo "=== Building Linux ${KERNEL_VERSION} with PREEMPT_RT ==="

# Step 1: Install dependencies
echo "[1/7] Installing build dependencies..."
sudo apt update
sudo apt install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    bc \
    dwarves \
    zstd \
    gawk \
    debhelper \
    libdw-dev

# Step 2: Download kernel
echo "[2/7] Downloading kernel..."
cd "$HOME"
if [ ! -f "linux-${KERNEL_VERSION}.tar.gz" ]; then
    curl -L -o "linux-${KERNEL_VERSION}.tar.gz" "$KERNEL_URL"
fi

# Step 3: Extract
echo "[3/7] Extracting kernel..."
if [ -d "$BUILD_DIR" ]; then
    echo "Removing existing build directory..."
    rm -rf "$BUILD_DIR"
fi
tar xf "linux-${KERNEL_VERSION}.tar.gz"
cd "$BUILD_DIR"

# Step 4: Configure
echo "[4/7] Configuring kernel..."

# Start from current running kernel config
cp /boot/config-$(uname -r) .config

# Fix Ubuntu-specific paths that don't exist in mainline
scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
scripts/config --set-str SYSTEM_REVOCATION_KEYS ""

# Disable debug info (otherwise modules are 8GB+ with DWARF symbols)
scripts/config --disable DEBUG_INFO
scripts/config --disable DEBUG_INFO_DWARF5
scripts/config --disable DEBUG_INFO_BTF

# Enable full preemption and PREEMPT_RT
scripts/config --enable PREEMPT
scripts/config --enable PREEMPT_RT

# AMD support
scripts/config --enable CPU_SUP_AMD
scripts/config --enable X86_AMD_PSTATE
scripts/config --enable AMD_PMF
scripts/config --enable AMD_PMC
scripts/config --enable AMD_HFI
scripts/config --module AMD_ISP_PLATFORM
scripts/config --enable DRM_AMD_ISP
scripts/config --module I2C_DESIGNWARE_AMDISP
scripts/config --module PINCTRL_AMDISP
scripts/config --enable AMD_IOMMU
scripts/config --module DRM_AMDGPU
scripts/config --enable DRM_AMD_DC

# Enable initramfs compression (likely missing from Ubuntu config)
scripts/config --enable RD_ZSTD

# Regenerate config with defaults for new options
make olddefconfig

echo "Kernel configured. Key settings:"
grep -E "PREEMPT_RT|AMD_ISP" .config | head -5

# Step 5: Build
echo "[5/7] Building kernel (this will take a while)..."
make -j$(nproc)

# Step 6: Install modules
echo "[6/7] Installing modules..."
sudo make modules_install

# Step 7: Install kernel
echo "[7/7] Installing kernel..."
sudo make install

# Update bootloader
echo "Updating GRUB..."
sudo update-grub

echo ""
echo "=== Build complete! ==="
echo ""
echo "Kernel installed: $(ls -la /boot/vmlinuz-${KERNEL_VERSION}* 2>/dev/null | tail -1)"
echo ""
echo "To boot the new kernel:"
echo "  1. Reboot your system"
echo "  2. Hold Shift (BIOS) or Esc (UEFI) to access GRUB menu"
echo "  3. Select 'Advanced options' and choose the ${KERNEL_VERSION} kernel"
echo ""
echo "After reboot, verify with:"
echo "  uname -r                    # Should show ${KERNEL_VERSION}"
echo "  uname -v                    # Should show PREEMPT_RT"
echo "  cat /sys/kernel/realtime    # Should show 1"
