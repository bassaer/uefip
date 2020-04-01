#TARGET    = main.efi
TARGET    = BOOTX64.EFI

CC        = x86_64-w64-mingw32-gcc
#CC        = gcc
INCLUDE   = -I/usr/include/efi -I/usr/include/efi/x86_64 -I/usr/include/efi/protocol
#CFLAGS    = -c -Wall ${INCLUDE} -e efi_main -fno-pie -fno-builtin -nostdlib -fno-stack-protector -fpic -DEFI_FUNCTION_WRAPPER -nostdinc
CFLAGS    = -ffreestanding -Wall -Wextra ${INCLUDE} -c
CRT_OBJ   = /usr/lib/crt0-efi-x86_64.o
LDS       = /usr/lib/elf_x86_64_efi.lds
LDFLAGS   = -nostdlib -znocombreloc -T ${LDS} -shared -Bsymbolic -L/usr/lib -lgnuefi -lefi lgcc

OVMF      = /usr/share/OVMF
DIST      = dist


.PHONY: install build run clean

all: run

install:
	sudo apt-get install -y gnu-efi ovmf gcc-mingw-w64-x86-64 binutils-mingw-w64
	cp ${OVMF}/OVMF_CODE.fd .
	cp ${OVMF}/OVMF_VARS.fd .


#%.o: %.c
#	${CC} ${CFLAGS} -o $@ $*.c

main.o: main.c
	${CC} -ffreestanding ${INCLUDE} -c -o $@ $<

%.so: %.o
	ld $< ${CRT_OBJ} ${LDFLAGS} -o $@


%.efi: %.so
	objcopy -j .text \
  -j .sdata               \
  -j .data                \
  -j .dynamic             \
  -j .dynsym              \
  -j .rel                 \
  -j .rela                \
  -j .reloc               \
  --target=efi-app-x86_64 \
  $<                      \
  ${DIST}/$@

#BOOTX64.EFI: main.o
#	${CC} -nostdlib -Wl,-T ${LDS} -shared -Bsymbolic -shared -e efi_main -o $@ $< ${CRT_OBJ} -L/usr/lib -L/usr/lib -lgnuefi -lefi -lgcc

BOOTX64.EFI:
	#${CC} -nostdlib -Wl,-dll -shared -Wl,--subsystem,10 -Bsymbolic -e efi_main -o $@ $< ${CRT_OBJ} -L/usr/lib -lgnuefi -lefi -lgcc
	x86_64-w64-mingw32-gcc -Wall -Wextra -e efi_main -nostdinc -nostdlib -fno-builtin -Wl,--subsystem,10 -o $@ main.c

fat.img: BOOTX64.EFI
	dd if=/dev/zero of=fat.img bs=1k count=1440
	mformat -i fat.img -f 1440 ::
	mmd -i fat.img ::/EFI
	mmd -i fat.img ::/EFI/BOOT
	mcopy -i fat.img BOOTX64.EFI ::/EFI/BOOT

#main.efi: main.c
#	gcc ${INCLUDE} -Wall -Wextra -e efi_main -nostdinc -nostdlib \
#  -fno-builtin -Wl,--subsystem,10, -o $@ $<



run: ${TARGET} fat.img
	qemu-system-x86_64 -bios /usr/share/ovmf/OVMF.fd -net none -usbdevice disk::fat.img


#run: ${TARGET}
#	cp ${OVMF}/OVMF_CODE.fd .
#	cp ${OVMF}/OVMF_VARS.fd .
#	qemu-system-x86_64 -cpu qemu64 \
#  -drive if=pflash,format=raw,unit=0,file=./OVMF_CODE.fd,readonly=on \
#  -drive if=pflash,format=raw,unit=1,file=./OVMF_VARS.fd \
#  -net none -hda fat:rw:${DIST} || true


clean:
	rm -rf *.o *.efi *.so dist *.fd *.img BOOTX64.EFI
