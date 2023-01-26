#!/bin/sh
DEVICES="0000:0a:00.0 0000:0a:00.1"

for DEVICE in $DEVICES; do
    echo "vfio-pci" >/sys/bus/pci/devices/$DEVICE/driver_override
done

modprobe -i vfio-pci
