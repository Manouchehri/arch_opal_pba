#!/bin/bash
# This script builds opal pbe image on arch linux.
# Copyright 2016 Konstantin Schlese.
# You can distribute this under GPL3+(Gnu Public License version 3 or greater).

# where to build the sources, binaries and image, this is a ram disk by default
BUILD_DIR:=/tmp/opal-initrd-build-dir

# size of pba partition need at least 64 mb for fat32
BOOT_PART_SIZE=$(shell echo "64 * 1024 * 1024" | bc)

# name of the partition image
BOOT_PART_NAME:=efiboot.img

# name of the whole disk image
BOOT_IMAGE:=pba.img

# this is an image name for cpio. Set the actual compression in opal-initrd.conf
INITRD_NAME:=opal.cpio.xz

# set this variable to use label instead of uuid
PBA_USE_LABEL:=1

# this is a label of efi PBA volume. Set it to something you like.
PBA_LABEL:="EFI_PBA1"

# this is a uid of PBA image. Set it to a random hexadecimal number of your liking.
PBA_UUID:=CAFE-0001

#GRUB_MODULES:= $(wildcard /usr/lib/grub/x86_64-efi/*.mod)
#GRUB_MODULES := $(GRUB_MODULES:.mod=)
#GRUB_MODULES := $(notdir $(GRUB_MODULES))

#grub modules to integrate 
GRUB_MODULES := ls cat echo cmp extcmd normal configfile test nativedisk ehci usb usbms acpi blocklist efi_gop efi_uga ata ahci part_msdos part_gpt video fat search search_label search_fs_uuid loadenv probe memdisk multiboot linux btrfs usb_keyboard gfxterm

# set this to your opal device for use with "make install"
OPAL_DRIVE=/dev/sde

# set this to the password of your opal device for use with "make install"
OPAL_PASS="your opal password here"

# this device will be overwritten with "make test". This is usefull to test if the boot disk is working ok by flashing it to usb stick.
TEST_DEVICE:=/dev/disk/by-id/usb-_USB_DISK_2.0_900028A0D1FFBF24-0:0

# how much sectors to skip at the beginning of the disk. Do not change this unless you know what you are doing.
BOOT_PART_OFFSET_SECTORS=2048

# This is the sector size of the image. Do not change this unless you know what you are doing.
SECTOR_SIZE=512

################# automaticly computed values begin here ###########################
#ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SEDUTIL_TARGET:=Release_x86_64
BOOT_PART_SIZE_SECTORS  := $(shell echo "$(BOOT_PART_SIZE) / $(SECTOR_SIZE)" | bc)
PART_OFFSET_BYTES       := $(shell echo "$(BOOT_PART_OFFSET_SECTORS) * $(SECTOR_SIZE)" | bc)
BOOT_IMAGE_SIZE         := $(shell echo "$(BOOT_PART_SIZE) + $(PART_OFFSET_BYTES) + 66 * $(SECTOR_SIZE)" | bc)
BOOT_IMAGE_SIZE_SECTORS := $(shell echo "$(BOOT_PART_OFFSET_SECTORS) + $(BOOT_PART_SIZE_SECTORS) + 66" | bc)
empty:=
space:= $(empty) $(empty)

all: $(BUILD_DIR)/$(BOOT_IMAGE)
	@echo "BOOT_PART_OFFSET_SECTORS $(BOOT_PART_OFFSET_SECTORS), BOOT_PART_SIZE_SECTORS $(BOOT_PART_SIZE_SECTORS)"
	@echo "BOOT_IMAGE_SIZE_SECTORS $(BOOT_IMAGE_SIZE_SECTORS)"

$(BUILD_DIR): Makefile
	mkdir -p $@

build: $(BUILD_DIR)
	if [ -d ./build ]; then unlink build; fi
	ln -s $< $@

sedutil: /usr/bin/patch
	if [ -d $@ ]; then git -C $@ reset --hard && git -C $@ pull; else  git clone https://github.com/Drive-Trust-Alliance/sedutil.git $@; fi
	git -C $@ checkout eb1852b0141e1d0b4fbaaea72f1044b9b9c0d814
	patch -p0 < nvme_admin_cmd.patch

# uncomment the following lines to use the stock linuxpba
#$(BUILD_DIR)/linuxpba: sedutil $(BUILD_DIR)
#	make -C ./sedutil/LinuxPBA CONF=$(SEDUTIL_TARGET)
#	cp ./sedutil/LinuxPBA/dist/$(SEDUTIL_TARGET)/GNU-Linux/linuxpba $@

# use this target to use my linuxpba
$(BUILD_DIR)/linuxpba: sedutil $(BUILD_DIR)
	make -C ./AskPasswordAndUnlock BUILD_DIR?=$(BUILD_DIR)

$(BUILD_DIR)/sedutil-cli: sedutil $(BUILD_DIR)
	make -C ./sedutil/linux/CLI CONF=$(SEDUTIL_TARGET)
	cp ./sedutil/linux/CLI/dist/$(SEDUTIL_TARGET)/GNU-Linux/sedutil-cli $@

$(BUILD_DIR)/$(INITRD_NAME): build $(BUILD_DIR)/sedutil-cli $(BUILD_DIR)/linuxpba opalcpio.conf
	./mkinitcpio -c opalcpio.conf -g $@

$(BUILD_DIR)/grub.cfg: grub.cfg.label.template grub.cfg.uuid.template
	if [ -n "$(PBA_USE_LABEL)" ]; \
	then \
	    ./grub.cfg.label.template $(PBA_LABEL) $(INITRD_NAME) > $@ ;\
	else \
	    ./grub.cfg.uuid.template $(PBA_UUID)   $(INITRD_NAME) > $@ ;\
	fi

$(BUILD_DIR)/grub_early.cfg: grub_early.cfg.label.template grub_early.cfg.uuid.template
	if [ -n "$(PBA_USE_LABEL)" ]; \
	then \
	    ./grub_early.cfg.label.template $(PBA_LABEL) > $@ ;\
	else \
	    ./grub_early.cfg.uuid.template $(PBA_UUID) > $@ ;\
	fi
	
$(BUILD_DIR)/grub.exe: $(BUILD_DIR)/grub_early.cfg /usr/bin/grub-mkimage
	#echo using modules $(GRUB_MODULES)
	grub-mkimage -O x86_64-efi -c $< -o $@ $(GRUB_MODULES)

$(BUILD_DIR)/$(BOOT_PART_NAME): $(BUILD_DIR)/$(INITRD_NAME) $(BUILD_DIR)/grub.exe $(BUILD_DIR)/grub.cfg /usr/bin/dd /usr/bin/mmd /usr/bin/mcopy
	dd if=/dev/zero of=$@ bs=$(SECTOR_SIZE) count=$(BOOT_PART_SIZE_SECTORS)
	mkfs.vfat -F 32 -n $(PBA_LABEL) -i $(subst -,$(empty),$(PBA_UUID)) $@
	mmd -i $@ ::/EFI
	mmd -i $@ ::/EFI/BOOT	
	mcopy -i $@ $< ::/$(INITRD_NAME)
	mcopy -i $@ /boot/vmlinuz ::/vmlinuz
	mcopy -i $@ $(BUILD_DIR)/grub.exe ::/EFI/BOOT/BOOTX64.EFI
	# copying grub and its modules
	mmd -i $@ ::/grub
	mmd -i $@ ::/grub/x86_64-efi
	mcopy -i $@ $(BUILD_DIR)/grub.cfg ::/grub/grub.cfg
	for i in /usr/lib/grub/x86_64-efi/*.mod ; do mcopy -i $@ $$i ::/grub/x86_64-efi/`basename $$i` ; done

#$(BUILD_DIR)/part_layout.txt: $(BUILD_DIR)
#	echo "label: gpt" > $@
#	echo "label-id: 2CADAD3A-8E41-49FE-B1C9-AFF8AA77B796" >> $@
#	echo "device: $(BOOT_IMAGE)" >> $@
#	echo "unit: sectors" >> $@
#	echo "first-lba: $(BOOT_PART_OFFSET_SECTORS)"
#	echo "$(BOOT_IMAGE)1 : start=        $(BOOT_PART_OFFSET_SECTORS), size=$(BOOT_PART_SIZE_SECTORS), type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF" >> $@
#	last-lba: 67550
#	echo "$(BOOT_IMAGE)1 : start=        2048, size=       65503, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=BD059804-8449-4976-958C-ECB1C7E6A524

#$(BUILD_DIR)/$(BOOT_IMAGE):  $(BUILD_DIR)/$(BOOT_PART_NAME) $(BUILD_DIR)/part_layout.txt
#	dd if=/dev/zero of=$@ bs=1 count=$(BOOT_IMAGE_SIZE)
#	sfdisk $@ < $(BUILD_DIR)/part_layout.txt
	
$(BUILD_DIR)/$(BOOT_IMAGE):  $(BUILD_DIR)/$(BOOT_PART_NAME) /usr/bin/sgdisk
	dd if=/dev/zero of=$@ bs=1 count=$(BOOT_IMAGE_SIZE)
	sgdisk -Z  $@
	sgdisk -i128 $@
	sgdisk -S128 -p -n 1:$(BOOT_PART_OFFSET_SECTORS):+$(BOOT_PART_SIZE_SECTORS) -t 1:EF00 -c 1:"EFI System" $@
	#sgdisk -A 1:set:0 $@ # set some attribute
	dd conv=notrunc if=$< of=$@ bs=$(SECTOR_SIZE) seek=$(BOOT_PART_OFFSET_SECTORS) count=$(BOOT_PART_SIZE_SECTORS)

install: $(BUILD_DIR)/$(BOOT_IMAGE) $(BUILD_DIR)/sedutil-cli
	$(BUILD_DIR)/sedutil-cli --loadPBAimage $(OPAL_PASS) $< $(OPAL_DRIVE)
	$(BUILD_DIR)/sedutil-cli --setMBRDone on $(OPAL_PASS) $(OPAL_DRIVE)
	$(BUILD_DIR)/sedutil-cli --setMBREnable on $(OPAL_PASS) $(OPAL_DRIVE)

test: $(BUILD_DIR)/$(BOOT_IMAGE) /usr/bin/sudo
	echo "!!!warning!!! the following operation will overwrite $(TEST_DEVICE)"
	read -i "<press any key to continue>"
	sudo dd if=$< of=$(TEST_DEVICE) bs=4096
	sync

clean: 
	rm -rf $(BUILD_DIR) build sedutil

