# armos —— 從零開始的 AArch64 作業系統核心（開發平台：QEMU virt）
#
# 完整原理、實測數據與踩過的坑：docs/guide/m0-build-and-boot.html
#   §2 動手步驟　§3 產物怎麼來的　§5 旗標逐條　§6 實測數據　§7 被推翻的直覺
# 註解裡的數值量於 binutils 2.38 / gcc 11.4.0 / QEMU 6.2.0 / gdb 12.1

CROSS   := aarch64-linux-gnu-
CC      := $(CROSS)gcc
OBJDUMP := $(CROSS)objdump
READELF := $(CROSS)readelf
QEMU    := qemu-system-aarch64
GDB     := gdb-multiarch            # Debian/Ubuntu 的套件名

SRC := kernel/boot.S                # 大寫 .S 才會過 C 前處理器
LD  := linker/kernel-qemu.ld

# 每個旗標對應一個「拿掉就會出現」的失敗：
#   -ffreestanding   別假設有 hosted 環境（純組語階段看不出差異，M1 進 C 才顯現）
#   -nostdlib        別連進 crt1.o，否則 _start 重複定義、又冒出 undefined main
#   -static          別產生需要動態連結器的執行檔，裸機沒有那個東西
#   -Wl,-T           用我們的佈局，不是 ld 內建的
#   --build-id=none  讓 .text 從 0x40000000 開始；否則 raw binary 首指令是 udf
WARN  := -Wall -Wextra -Werror
FLAGS := -ffreestanding -nostdlib -static -Wl,-T,$(LD) -Wl,--build-id=none

all: build/kernel.elf

# $(LD) 必須列進相依：少了它，改完 linker script 會沿用舊 ELF 而且建置「成功」
build/kernel.elf: $(SRC) $(LD) | build
	$(CC) $(WARN) $(FLAGS) -o $@ $(SRC)

build:
	mkdir -p build

# 核心還不會輸出任何字，這是唯一的靜態檢查手段
dump: build/kernel.elf
	$(OBJDUMP) -d $<
	@$(READELF) -h $< | grep 'Entry point'
	@$(READELF) -l $<

# 畫面全黑是正確的，UART 要到 M1。離開：先按 Ctrl-A，放開，再按 X
qemu: build/kernel.elf
	$(QEMU) -M virt -cpu cortex-a72 -nographic -kernel $<

# 唯一能證明 CPU 真的在執行的方法：-S 停在第一條指令，-s 開 GDB port 1234。
# 序列埠寫檔而不用 -nographic，否則會跟前景的 GDB 搶同一個終端機。
debug: build/kernel.elf
	@if ss -ltn 2>/dev/null | grep -q ':1234 '; then \
	    echo "port 1234 已被佔用，先清掉舊的：pkill -f qemu-system-aarch64"; \
	    exit 1; \
	fi
	$(QEMU) -M virt -cpu cortex-a72 -display none -serial file:build/serial.log \
	        -kernel $< -S -s & \
	qemu_pid=$$!; \
	$(GDB) -q $< \
	    -ex 'target remote :1234' \
	    -ex 'break halt_loop' \
	    -ex 'continue' -ex 'print $$x0' \
	    -ex 'continue' -ex 'print $$x0'; \
	kill $$qemu_pid 2>/dev/null || true

# 0x40000000 的出處：輸出裡的 memory 節點（需要 device-tree-compiler）
dtb: | build
	$(QEMU) -M virt -cpu cortex-a72 -machine dumpdtb=build/virt.dtb -nographic
	dtc -I dtb -O dts build/virt.dtb

clean:
	rm -rf build

.PHONY: all dump qemu debug dtb clean
