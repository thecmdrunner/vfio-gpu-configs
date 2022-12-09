# VFIO Dual-GPU Configuration

**VFIO setup configuration for my system that does Linux + Windows 11 with GPU acceleration simulatenously.**

This is very useful because I still run into programs that are better suited (or only available) on Windows, like Teamviewer, Office 365, Powershell, etc.

## Operating Systems support

![Windows](https://img.shields.io/badge/Windows-blue?style=for-the-badge&logo=Windows-11&logoColor=white&color=0078D4)
![Linux](https://img.shields.io/badge/Linux-black?style=for-the-badge&logo=Linux&logoColor=white&color=2d2d2d)
![BSD](https://img.shields.io/badge/BSD-black?style=for-the-badge&logo=FreeBSD&logoColor=white&color=AB2B28)
![Mac](https://img.shields.io/badge/macOS-black?style=for-the-badge&logo=Apple&logoColor=black&color=white)

| **Guest OS**                                                              | **Notes**                                                                                                                                                                                             |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Windows 10/11                                                             | Windows 11 may require [`swtpm`](https://github.com/stefanberger/swtpm) and OVMF's `secboot.fd` UEFI variant [unless bypassed](https://www.tomshardware.com/how-to/bypass-windows-11-tpm-requirement) |
| Linux Distros, BSDs                                                       | First class QEMU/KVM support for Linux distros. BSDs also work OOTB in my brief testing.                                                                                                              |
| Mac OS ([with optimizations](https://github.com/sickcodes/osx-optimizer)) | Mac OS works [**with a supported GPU**](https://dortania.github.io/GPU-Buyers-Guide/). _(my GT 710 plays 4K videos just fine)_                                                                        |

<details>
<summary><b>Here's my setup that I've used to test everything</b></summary>

| **Category**    | **Hardware**                          | **Notes**                                                                                 |
| --------------- | ------------------------------------- | ----------------------------------------------------------------------------------------- |
| **CPU**         | AMD Ryzen 9 3900X                     |                                                                                           |
| **Motherboard** | Gigabyte Aorus X570 Elite WiFi        | _I bought this board, since Gigabyte usually has good IOMMU isolation_                    |
| **GPUs**        | 2 x NVIDIA GT 710 - (Asus & Gigabyte) | _(yes they are from the pandemic times)_                                                  |
| **Host OS**     | Fedora 37 w/ KDE Plasma               | This setup is also tested on Ubuntu 22.10 and instructions are provided along with Fedora |

</details>

# 🚀 Getting Started with the Basics

**Follow [this guide](https://gitlab.com/risingprismtv/single-gpu-passthrough/-/wikis/home) by RisingPrismTV, or the brief instructions mentioned below.** _(taken from the guide)_

<!-- These link to already excellent guides made by others to avoid repetitions and potentially contradicting instructions from my side. -->

<details>
<summary><b style="font-size: 1.3rem;">1. Enable virtualization in UEFI/BIOS</b></summary>
This varies between AMD and Intel platforms. Refer to your motherboard's user manual.

**_For example:_**

- Intel (ASUS): https://www.asus.com/support/FAQ/1043786/

</details>

<details>
<summary><b style="font-size: 1.3rem;">2. Configure GRUB</b></summary>

- Add IOMMU flags in the `GRUB_CMDLINE_LINUX` line in `/etc/default/grub`

  - **_For AMD CPUs:_** `amd_iommu=on iommu=pt`

    **_For Intel CPUs:_** `intel_iommu=on iommu=pt`

  - `iommu=pt` leads to [less overhead](https://access.redhat.com/documentation/en-us/red_hat_virtualization/4.1/html/installation_guide/appe-configuring_a_hypervisor_host_for_pci_passthrough) and thus [better performance](https://www.reddit.com/r/Proxmox/comments/hhx77k/the_importance_of_iommupt_with_gpu_pass_through_i/).

    **For example:**

    ```bash
    GRUB_CMDLINE_LINUX="rhgb quiet amd_iommu=on iommu=pt"
    ```

- Update grub

  ```bash
  # Ubuntu
  sudo grub-mkconfig -o /boot/grub/grub.cfg

  # Fedora/CentOS/RHEL
  sudo grub2-mkconfig -o /etc/grub2-efi.cfg
  ```

- Reboot your system and verify that IOMMU flags are enabled.

  ```bash
  cat /proc/cmdline | grep iommu
  ```

> Adding **`rd.driver.pre=vfio-pci`** may help if `vfio-pci` isn't being loaded instead of the vendor drivers (`nvidia` or `amdgpu`), but is not needed on most systems.

</details>

<details>
<summary><b style="font-size: 1.3rem;">3. Check your IOMMU grouping</b></summary>

- You can only passthrough all the devices in an IOMMU group.

  That's why it is best if your GPU is in its own separate IOMMU group, or the components of your GPU are in their own isolated group.

- If not, then you will need to also passthrough every other device in that IOMMU group, which isn't always desirable or possible.

- To check your IOMMU groups, run this in your terminal: _(source: [Archwiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Ensuring_that_the_groups_are_valid))_

  ```bash
  #!/bin/bash
  shopt -s nullglob
  for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
  done;
  ```

    <details>
    <summary><i>My sample output</i></summary>

  <b>Notice that I have two GT 710 GPUs in IOMMU Group 22 and 25 respectively, each having a VGA and Audio component with no other device in the group.</b>

  ```bash
  IOMMU Group 0:
        00:01.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
  IOMMU Group 1:
        00:01.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse GPP Bridge [1022:1483]
  IOMMU Group 2:
        00:01.2 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse GPP Bridge [1022:1483]
  IOMMU Group 3:
        00:02.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
  IOMMU Group 4:
        00:03.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
  IOMMU Group 5:
        00:03.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse GPP Bridge [1022:1483]
  IOMMU Group 6:
        00:04.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
  IOMMU Group 7:
        00:05.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
  IOMMU Group 8:
        00:07.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
  IOMMU Group 9:
        00:07.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Internal PCIe GPP Bridge 0 to bus[E:B] [1022:1484]
  IOMMU Group 10:
        00:08.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Host Bridge [1022:1482]
  IOMMU Group 11:
        00:08.1 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Internal PCIe GPP Bridge 0 to bus[E:B] [1022:1484]
  IOMMU Group 12:
        00:14.0 SMBus [0c05]: Advanced Micro Devices, Inc. [AMD] FCH SMBus Controller [1022:790b] (rev 61)
        00:14.3 ISA bridge [0601]: Advanced Micro Devices, Inc. [AMD] FCH LPC Bridge [1022:790e] (rev 51)
  IOMMU Group 13:
        00:18.0 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 0 [1022:1440]
        00:18.1 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 1 [1022:1441]
        00:18.2 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 2 [1022:1442]
        00:18.3 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 3 [1022:1443]
        00:18.4 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 4 [1022:1444]
        00:18.5 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 5 [1022:1445]
        00:18.6 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 6 [1022:1446]
        00:18.7 Host bridge [0600]: Advanced Micro Devices, Inc. [AMD] Matisse/Vermeer Data Fabric: Device 18h; Function 7 [1022:1447]
  IOMMU Group 14:
        01:00.0 Non-Volatile memory controller [0108]: Samsung Electronics Co Ltd NVMe SSD Controller 980 [144d:a809]
  IOMMU Group 15:
        02:00.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Matisse Switch Upstream [1022:57ad]
  IOMMU Group 16:
        03:02.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Matisse PCIe GPP Bridge [1022:57a3]
  IOMMU Group 17:
        03:03.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Matisse PCIe GPP Bridge [1022:57a3]
  IOMMU Group 18:
        03:04.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Matisse PCIe GPP Bridge [1022:57a3]
  IOMMU Group 19:
        03:08.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Matisse PCIe GPP Bridge [1022:57a4]
        07:00.0 Non-Essential Instrumentation [1300]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Reserved SPP [1022:1485]
        07:00.1 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
        07:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
  IOMMU Group 20:
        03:09.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Matisse PCIe GPP Bridge [1022:57a4]
        08:00.0 SATA controller [0106]: Advanced Micro Devices, Inc. [AMD] FCH SATA Controller [AHCI mode] [1022:7901] (rev 51)
  IOMMU Group 21:
        03:0a.0 PCI bridge [0604]: Advanced Micro Devices, Inc. [AMD] Matisse PCIe GPP Bridge [1022:57a4]
        09:00.0 SATA controller [0106]: Advanced Micro Devices, Inc. [AMD] FCH SATA Controller [AHCI mode] [1022:7901] (rev 51)
  IOMMU Group 22:
        04:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK208B [GeForce GT 710] [10de:128b] (rev a1)
        04:00.1 Audio device [0403]: NVIDIA Corporation GK208 HDMI/DP Audio Controller [10de:0e0f] (rev a1)
  IOMMU Group 23:
        05:00.0 Network controller [0280]: Intel Corporation Dual Band Wireless-AC 3168NGW [Stone Peak] [8086:24fb] (rev 10)
  IOMMU Group 24:
        06:00.0 Ethernet controller [0200]: Intel Corporation I211 Gigabit Network Connection [8086:1539] (rev 03)
  IOMMU Group 25:
        0a:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK208B [GeForce GT 710] [10de:128b] (rev a1)
        0a:00.1 Audio device [0403]: NVIDIA Corporation GK208 HDMI/DP Audio Controller [10de:0e0f] (rev a1)
  IOMMU Group 26:
        0b:00.0 Non-Essential Instrumentation [1300]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse PCIe Dummy Function [1022:148a]
  IOMMU Group 27:
        0c:00.0 Non-Essential Instrumentation [1300]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Reserved SPP [1022:1485]
  IOMMU Group 28:
        0c:00.1 Encryption controller [1080]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse Cryptographic Coprocessor PSPCPP [1022:1486]
  IOMMU Group 29:
        0c:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Matisse USB 3.0 Host Controller [1022:149c]
  IOMMU Group 30:
        0c:00.4 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Starship/Matisse HD Audio Controller [1022:1487]
  ```

  </details>

- If your IOMMU groups aren't very isolated, trying enabling "ACS/ARI" option for better IOMMU grouping on most motherboards.

**Also checkout:**

- [Archwiki - PCI Passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)

- [ASRock Deskmini ACS](https://www.reddit.com/r/ASRock/comments/pfza16/deskmini_x300_bios_with_acs_enable/)

- [Unraid GPU passthrough](https://forums.unraid.net/topic/87557-guide-asrock-x570-taichi-vm-w-hardware-passthrough/)

- [Ryzen 5000 APUs IOMMU](https://www.reddit.com/r/VFIO/comments/pd7ktr/comment/haspc9y/)

</details>

<details>
<summary><b style="font-size: 1.3rem;">4. Install and setup Libvirt</b></summary>

- ##### Fedora:

```bash
# Install packages from virtualization group
sudo dnf install "@virtualization" -y
```

- ##### Ubuntu:

```bash
# Installing virt-manager should grab all dependencies?
sudo apt install virt-manager -y
```

### 5. Start Libvirt

- Reboot the system for sanity
- Enable `libvirtd` service

```bash
sudo systemctl enable --now libvirtd
```

</details>

# GPU Passthrough

**This is the interesting sutff you've come for!**

[WIP]

## Credits (and Helpful links!)

[WIP]

- [Complete Single GPU Passthrough](https://github.com/QaidVoid/Complete-Single-GPU-Passthrough) by QaidVoid
  - [Troubleshooting guide](https://docs.google.com/document/d/17Wh9_5HPqAx8HHk-p2bGlR0E-65TplkG18jvM98I7V8/) (from the same repository)
