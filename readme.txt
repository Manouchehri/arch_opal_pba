The purpose of this package is to enable Arch Linux users to use OPAL SED drives. This package generates PBA(Pre Boot Authentification) (Linux-)Image for Arch Linux users 
This image unlocks the drive and reboots so that the real operating system can be loaded.

Required software:
- linux headers
- base-devel package on arch linux (gcc, make)
- git
- mkinitcpio (will be probably changed in the future)
- mtools
- grub2
- util-linux(sfdisk, dd)

Usage:
- edit Makefile (the relevant parts are commented) and run make.
- flash build/pba.img on usb stick and boot from it to test if it works (just edit TEST_DEVICE variable in Makefile and run "make test")
- edit OPAL_* variables and run make install to install pba.img as a pre boot image.

Current Issues:
- I don't know if the users of Linux kernel < 4.4 need the nvme_admin_cmd.patch applied. Erase patch applying step in makefile it if you get nvme_* error.
  It is in sedutil make target, just after "git clone" step. As of now it's on line 74.
- mine linuxpba from AskPasswordAndUnlock directory  segfaults after entering the password, just reboot after that, the drive will be unlocked.
- using UUID doesn't quite work because the grub root device is not found at early grub config. You can however get past this step in grub shell
  if you do "ls" and then set root="correct device" and then "configfile /grub/grub.cfg" command.
  If you try to run from usb stick with UUID mode, try executing "configfile (usb0,gpt1)/grub/grub.cfg" or use "ls" command to found out the correct device.
  I advise to use LABEL method for now (the default).

