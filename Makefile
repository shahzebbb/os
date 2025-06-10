SRC     = ./src
BUILD   = $(SRC)/build
NASM    = nasm
QEMU    = qemu-system-x86_64
BIN     = $(BUILD)/bootloader.bin
IMG     = $(BUILD)/bootloader.img

# === DEFAULT TARGET === 
all: $(IMG)

# === BUILD BOOTLOADER ===
$(BIN): $(SRC)/bootloader.asm
	@mkdir -p $(BUILD)
	$(NASM) -f bin $(SRC)/bootloader.asm -o $(BIN)


# === CREATE DISK IMAGE ===
$(IMG): $(BIN)
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	dd if=$(BIN) of=$(IMG) conv=notrunc

# === RUN QEMU ===
run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG)

# === CLEAN UP ===
clean:
	rm -rf $(BUILD)
