TARGET    = BOOTX64.EFI

CC        = x86_64-w64-mingw32-gcc
CFLAGS    = -Wall -Wextra -Iinclude -nostdinc -nostdlib -fno-builtin -Wl,--subsystem,10

OVMF      = /usr/share/OVMF

.PHONY: install build run screenshot clean

all: run

install:
	sudo apt-get install -y gnu-efi ovmf gcc-mingw-w64-x86-64 binutils-mingw-w64
	cp ${OVMF}/OVMF_CODE.fd .
	cp ${OVMF}/OVMF_VARS.fd .

BOOTX64.EFI: main.c
	${CC} ${CFLAGS} -e efi_main -o $@ $<

fat.img: BOOTX64.EFI
	dd if=/dev/zero of=fat.img bs=1k count=1440
	mformat -i fat.img -f 1440 ::
	mmd -i fat.img ::/EFI
	mmd -i fat.img ::/EFI/BOOT
	mcopy -i fat.img BOOTX64.EFI ::/EFI/BOOT

run: ${TARGET} fat.img main.c
	qemu-system-x86_64 -bios /usr/share/ovmf/OVMF.fd -net none -usbdevice disk::fat.img

screenshot:
	gnome-screenshot --window --delay=5 -f screenshot.png

clean:
	rm -rf *.o *.efi *.so dist *.fd *.img ${TARGET}
