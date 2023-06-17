# Ubuntu setup

- Make script in initramfs:

```bash
sudo nano /etc/initramfs-tools/scripts/init-top/01-vfio-pci-override-vga.sh
```

Here's the script:

TLDR;

This script determines the GPU addresses by itself, so we don't have to specify any hard-coded values.

It checks if the GPU is marked as "boot VGA", i.e., if your UEFI has marked it as the primary display out.

If it is *not* a "boot VGA", then bind the `vfio-pci` driver to it, and load the module.

```bash
#!/bin/sh

for i in /sys/bus/pci/devices/*/boot_vga
do
    if [ $(cat "$i") -eq 0 ]; then
        GPU="${i%/boot_vga}"
        for part in `ls -d $(echo $GPU | cut -f1 -d'.').*`
        do
            echo "vfio-pci" > "$part/driver_override"
            BIND_DEVICE=`echo "$part" | cut -d '/' -f 6`
            echo "$BIND_DEVICE" >> /sys/bus/pci/drivers/vfio-pci/bind
        done
    fi
done
```

- Set right permissions:

```bash
sudo chmod 744 /etc/initramfs-tools/scripts/init-top/01-vfio-pci-override-vga.sh
```

- Update initramfs:

```bash
sudo update-initramfs -u
```

- Reboot and verify: `lspci -nnk`


## Single GPU P


Setup Livbirt hooks as you normally would.
(Follow SomeOrdinaryGamers' video on this...)

```bash
sudo mkdir -p /etc/libvirt/hooks
sudo wget 'https://raw.githubusercontent.com/PassthroughPOST/VFIO-Tools/master/libvirt_hooks/qemu'      -O /etc/libvirt/hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
sudo service libvirtd restart
systemctl enable --now libvirtd
```

(Follow SomeOrdinaryGamers' video for this...)


### Start script

```bash
mkdir -p /etc/libvirt/hooks/qemu.d/win10/prepare/begin
touch /etc/libvirt/hooks/qemu.d/win10/prepare/begin/start.sh
chmod +x /etc/libvirt/hooks/qemu.d/win10/prepare/begin/start.sh
```

```bash
#!/bin/bash
set -x

source "/etc/libvirt/hooks/kvm.conf"

# Stop display manager
systemctl stop display-manager
# killall gdm-x-session
# rc-service xdm stop

sleep 1

# Unbind VTconsoles: might not be needed
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Unbind EFI Framebuffer
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

sleep 1

# Unload NVIDIA kernel modules
modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia

# Unload AMD kernel module
# modprobe -r amdgpu

# Detach GPU devices from host
# Use your GPU and HDMI Audio PCI host device
virsh nodedev-detach $VIRSH_GPU_VIDEO
virsh nodedev-detach $VIRSH_GPU_AUDIO

# Load vfio module
modprobe vfio-pci
```

### Stop script

```bash
#!/bin/bash
set -x

source "/etc/libvirt/hooks/kvm.conf"

# Attach GPU devices to host
# Use your GPU and HDMI Audio PCI host device
virsh nodedev-reattach $VIRSH_GPU_VIDEO
virsh nodedev-reattach $VIRSH_GPU_AUDIO

# Unload vfio module
modprobe -r vfio-pci

sleep 1

# Load AMD kernel module
#modprobe amdgpu

# Rebind framebuffer to host
echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

sleep 1

# Load NVIDIA kernel modules
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia_uvm
modprobe nvidia

# Bind VTconsoles: might not be needed
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# Restart Display Manager
systemctl start display-manager
# rc-service xdm start
```
