#!/bin/bash
OVMF_PATH=/usr/share/ovmf/ovmf_x64.bin

if [ -z ${OVMF_PATH} ]
then
    echo no ovmf uefi image  was found, aborting
else
    qemu-system-x86_64 -bios ${OVMF_PATH} ./build/efiboot.img
fi
