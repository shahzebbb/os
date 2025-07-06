NASM    = nasm
QEMU    = qemu-system-x86_64
CC      = i686-elf-gcc      
LD      = i686-elf-ld
OBJCOPY = i686-elf-objcopy

SRC     = ./src
BUILD   = $(SRC)/build

BOOTLOADER_BIN = $(BUILD)/bootloader.bin
KERNEL_ELF     = $(BUILD)/kernel.elf
KERNEL_BIN     = $(BUILD)/kernel.bin
IMG            = $(BUILD)/bootloader.img

# === DEFAULT TARGET === 
all: $(IMG)

# === CREATE BUILD FOLDER ===
$(BUILD):
	mkdir -p $(BUILD)

# === BUILD BOOTLOADER ===
$(BOOTLOADER_BIN): $(BUILD)
	$(NASM) -f bin $(SRC)/bootloader.asm -o $@

# === BUILD KERNEL BINARIES ===
# $(BUILD)/start.o: $(SRC)/start.asm
# 	$(NASM) -f elf32 $< -o $@

$(BUILD)/start.o: $(SRC)/start.S
	$(CC) -c -o $@ $< 

$(BUILD)/kernel.o: $(SRC)/kernel.c
	$(CC) -m32 -ffreestanding -c $< -o $@

# ==== LINK KERNEL BINARIES TOGETHER ===
$(KERNEL_BIN): $(BUILD)/start.o $(BUILD)/kernel.o $(SRC)/linker.ld
	$(LD) -m elf_i386 -T $(SRC)/linker.ld -o $@ $^

# $(KERNEL_BIN): $(KERNEL_ELF)
# 	$(OBJCOPY) -O binary $< $@

# === CREATE DISK IMAGE ===
$(IMG): $(BOOTLOADER_BIN) $(KERNEL_BIN)
	dd if=/dev/zero of=$(IMG) bs=512 count=2880 status=none
	mkfs.fat -F 12 $(IMG) 
	dd if=$(BOOTLOADER_BIN) of=$(IMG) conv=notrunc status=none
	mcopy -i $(IMG) $(KERNEL_BIN) "::KERNEL.BIN"
	

# === RUN QEMU ===
run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG),if=floppy

# === CLEAN UP ===
clean:
	rm -rf $(BUILD)

debug:
	bochs -f bochsrc -dbg

run_reset: clean run
