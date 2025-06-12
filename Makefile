SRC     = ./src
BUILD   = $(SRC)/build
NASM    = nasm
QEMU    = qemu-system-x86_64
BIN     = $(BUILD)/bootloader.bin
IMG     = $(BUILD)/bootloader.img

# === DEFAULT TARGET === 
all: $(IMG)

# === BUILD BOOTLOADER ===
$(BIN):
	@mkdir -p $(BUILD)
	$(NASM) -f bin $(SRC)/bootloader.asm -o $(BIN)

$(BUILD)/main.bin:
	@mkdir -p $(BUILD)
	$(NASM) -f bin $(SRC)/main.asm -o $(BUILD)/main.bin

# === CREATE DISK IMAGE ===
$(IMG): $(BIN) $(BUILD)/main.bin
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	dd if=$(BIN) of=$(IMG) conv=notrunc
	dd if=$(BUILD)/main.bin of=$(IMG) bs=512 seek=1 conv=notrunc

# === RUN QEMU ===
run: $(IMG)
	$(QEMU) -drive format=raw,file=$(IMG)

# === CLEAN UP ===
clean:
	rm -rf $(BUILD)
