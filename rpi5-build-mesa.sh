echo installing deps
sudo apt-get install -y \
	python3-mako libxrandr-dev libdrm-dev libgbm-dev libxext-dev libxdamage-dev \
	libxfixes-dev libexpat1-dev \
	libvulkan-dev \
	llvm-dev clang libclang-dev \
	libx11-dev libxcb-glx0-dev libxcb-shm0-dev libxcb-keysyms1-dev libx11-xcb-dev \
	libxcb-dri2-0-dev libxcb-dri3-dev libxcb-present-dev  \
	libxshmfence-dev libxxf86vm-dev \
	libxkbcommon-dev libxkbcommon-x11-dev \
	libvdpau-dev libva-dev libclc-16-dev \
	libelf-dev libzstd-dev
	
# for wayland support (not supported on rpi5)
#sudo apt-get install libwayland-dev libegl1-mesa-dev libgles2-mesa-dev libwayland-dev libwayland-egl-backend-dev libwayland-cursor-dev libwayland-server-dev libwayland-client-dev

# do not install meson here because apt version is lower than mesa required
# clone repo and use system PATH instead (mesa is just a python package)
# from https://github.com/mesonbuild/meson/releases

if [ ! -d mesa ] ; then
echo clone
git clone https://gitlab.freedesktop.org/mesa/mesa.git
fi
cd mesa
echo meson build
# swrast is deprecated in favor of llvmpipe,softpipe
# platforms=wayland is not used here because wayland is unsupported on rpi5 (otherwise set -Dplatforms=x11,wayland).
# make sure that dtoverlay=vc4-kms-v3d is set in /boot/firmware/config.txt
LLVM_CONFIG=llvm-config-16 meson setup --wipe build/ \
 -Dgallium-drivers=vc4,v3d,zink,llvmpipe,softpipe \
 -Dvulkan-drivers=broadcom \
 -Dplatforms=x11 \
 -Dvideo-codecs=all \
 -Dbuildtype=release
 
echo ninja build
ninja -C build/
echo ninja build install
sudo ninja -C build/ install
echo done

echo "now supposedly run an application with zink through $ MESA_LOADER_DRIVER_OVERRIDE=zink <your_application>"
