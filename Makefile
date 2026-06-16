ASM			= nasm

SRC_DIR		= src
BUILD_DIR	= build

.PHONY: all disk_image kernel bootloader clean build_dir run

# ------ Disk Image ------
disk_image: $(BUILD_DIR)/os.img

$(BUILD_DIR)/os.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/os.img bs=512 count=2880
	mkfs.fat -F 12 -n "FOS" $(BUILD_DIR)/os.img
	dd if=$(BUILD_DIR)/boot.bin of=$(BUILD_DIR)/os.img conv=notrunc
	mcopy -i $(BUILD_DIR)/os.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

# ------ Bootloader ------
bootloader: $(BUILD_DIR)/boot.bin

$(BUILD_DIR)/boot.bin: build_dir
	$(ASM) $(SRC_DIR)/boot/boot.asm -f bin -o $(BUILD_DIR)/boot.bin

# ------ Kernel ------
kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: build_dir
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

# ------ Build Dir ------
build_dir:
	mkdir -p $(BUILD_DIR)

# ------ Clean ------
clean:
	rm -rf $(BUILD_DIR)

# ------ Run ------
run:
	qemu-system-i386 -fda build/os.img