some virtualbox tips and tricks:

# install guest addons in guest
after creating a vm, install the guest addons inside the guest (i.e. inside the vm).

the guest addons come as an .iso file with the virtualbox host application. the path depends on the host OS, e.g. on macos it is:
``` /Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso```
attach this file to the vm and run the respective install script there (depending on the guest OS, you may need have need to install some system libraries first).
on macos, you may not be able to navigate to the iso with the file picker, because macos does not let you navigate into a .app, even though a .app is just a directory.
you can navigate there to copy the .iso (just ~60MB) somewhere else, where you can pick it, using the terminal: ``` $ open /Applications/VirtualBox.app/Contents/MacOS```

# boot order is not preserved across guest reboots
the boot order can be changed inside the guest by:
1. enter the uefi menu (e.g. run the `exit` command in the efi shell)
2. in the change boot order menu, press -/+ to change the order (you may also add a new entry to the boot order in an adjacent menu to boot linux, with grub
usually found in \EFI\debian\grubx64.efi)
3. this boot order will vanish on reboot, but
4. when logged into the guest OS, edit the file `/boot/efi/startup.nsh` (may need to be created)
5. and just write `fs0:\EFI\debian\grubx64.efi` into it, to automatically boot a custom efi file on system boot instead (ignores boot order)

# use a linux vm to access an ext4 file system on macos
macos lacks ext4 FS drivers, but you can use a linux vm to access that fs.

1. set up a linux vm (e.g. debian)
2. create a virtual raw disk mount file for virtualbox with (here, for partition 2 on disk 5)  
    2.1. `sudo VBoxManage createmedium disk --filename ~/disk5s2.vmdk --format=VMDK --variant RawDisk --property RawDrive=/dev/disk5s2`
    2.2. you need to chown and chmod the file for rw permissions on non-root `sudo chown -R $USER:staff disk5s2.vmdk && sudo chmod -R u+rw disk5s2.vmdk`
    2.3. you may also need to the change the rights of the raw disk to allow writing to raw disk for non-root: `ls -l /dev/disk5s2` - should be -rw-rw, otherwise run `sudo chmod 660 /dev/disk5s2` (resets on host reboot)
    2.4. note: deleting that .vmdk file (eventually) does not clean it up properly. to do this, first remove the disk from the vm, and then run `sudo VBoxManage closemedium disk ~/disk5s2.vmdk --delete`
4. on macos (unknown status on linux), virtualbox will not have access to the raw disk, even through this handle. add yourself to the operator group, which
does have those rights `sudo dseditgroup -o edit -a $USER -t user operator`
5. in virtualbox, add a hard disk to the usb controller (did not work with the other controller) via disk image file and select the .vmdk file
6. done
