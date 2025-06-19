SRC     = ./src
BUILD   = $(SRC)/build
NASM    = nasm
QEMU    = qemu-system-x86_64
BIN     = $(BUILD)/bootloader.bin
IMG     = $(BUILD)/bootloader.img

# === DEFAULT TARGET === 
all: $(IMG)
# === BUILD BOOTLOADER ===
binaries:
	@mkdir -p $(BUILD)
	$(NASM) -f bin $(SRC)/bootloader.asm -o $(BUILD)/bootloader.bin
	$(NASM) -f bin $(SRC)/start.asm -o $(BUILD)/start.bin	

# === CREATE DISK IMAGE ===
$(IMG): binaries
	dd if=/dev/zero of=$(IMG) bs=512 count=2880 status=none
	mkfs.fat -F 12 $(IMG) 
	dd if=$(BIN) of=$(IMG) conv=notrunc status=none
	mcopy -i $(IMG) $(BUILD)/start.bin "::START.bin"
	

# === RUN QEMU ===
run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG),if=floppy

# === CLEAN UP ===
clean:
	rm -rf $(BUILD)

run_reset: clean run
