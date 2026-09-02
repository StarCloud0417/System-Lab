# armos —— 從零開始的 AArch64 作業系統核心（開發平台：QEMU virt）
#
# 完整原理、實測數據與踩過的坑：docs/guide/m0-build-and-boot.html
#   §2 動手步驟　§3 產物怎麼來的　§5 旗標逐條　§6 實測數據　§7 被推翻的直覺
# 註解裡的數值量於 binutils 2.38 / gcc 11.4.0 / QEMU 6.2.0 / gdb 12.1

# 有些發行版的裸機工具鏈叫 aarch64-none-elf-；改這裡，check-env 會跟著走
CROSS   := aarch64-linux-gnu-
CC      := $(CROSS)gcc
OBJDUMP := $(CROSS)objdump
READELF := $(CROSS)readelf
QEMU    := qemu-system-aarch64
# virtualization=on 讓 QEMU 在 EL2 交接，模擬樹莓派韌體的行為
MACHINE     := virt
MACHINE_EL2 := virt,virtualization=on
# gdb-multiarch 是 Debian/Ubuntu 的套件名；一般的 gdb 認不得 aarch64 目標
GDB     := gdb-multiarch

# 大寫 .S 才會過 C 前處理器（小寫 .s 不會）
SRC := kernel/boot.S
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

# 檢查工具鏈。缺工具會失敗，版本與文件不同只提醒。
check-env:
	@CROSS='$(CROSS)' bash scripts/check-env.sh

# 核心還不會輸出任何字，這是唯一的靜態檢查手段
dump: build/kernel.elf
	$(OBJDUMP) -d $<
	@$(READELF) -h $< | grep 'Entry point'
	@$(READELF) -l $<

# 畫面全黑是正確的，UART 驅動要到 M2。離開：先按 Ctrl-A，放開，再按 X
qemu: build/kernel.elf
	$(QEMU) -M $(MACHINE) -cpu cortex-a72 -nographic -kernel $<

# 同上，但在 EL2 交接。核心會自己降到 EL1，畫面一樣是全黑的。
qemu-el2: build/kernel.elf
	$(QEMU) -M $(MACHINE_EL2) -cpu cortex-a72 -nographic -kernel $<

# 唯一能證明 CPU 真的在執行的方法：-S 停在第一條指令，-s 開 GDB port 1234。
# 序列埠寫檔而不用 -nographic，否則會跟前景的 GDB 搶同一個終端機。
debug: build/kernel.elf
	@if ss -ltn 2>/dev/null | grep -q ':1234 '; then \
	    echo "port 1234 已被佔用。清場：pkill -x qemu-system-aar"; \
	    echo "（行程名被截成 15 字元；用全名比對不到，加 -f 又會殺到自己的 shell）"; \
	    exit 1; \
	fi
	$(QEMU) -M $(MACHINE) -cpu cortex-a72 -display none -serial file:build/serial.log \
	        -kernel $< -S -s & \
	qemu_pid=$$!; \
	$(GDB) -q $< \
	    -ex 'target remote :1234' \
	    -ex 'break halt_loop' \
	    -ex 'continue' -ex 'print $$x10' \
	    -ex 'continue' -ex 'print $$x10'; \
	kill $$qemu_pid 2>/dev/null || true

# 同 debug，但在 EL2 交接。兩者印出的 x10 應該一模一樣 —— 那正是降級有效的證明。
debug-el2: build/kernel.elf
	@$(MAKE) --no-print-directory debug MACHINE='$(MACHINE_EL2)'

# 0x40000000 的出處：輸出裡的 memory 節點（需要 device-tree-compiler）
dtb: | build
	$(QEMU) -M $(MACHINE) -cpu cortex-a72 -machine dumpdtb=build/virt.dtb -nographic
	dtc -I dtb -O dts build/virt.dtb

clean:
	rm -rf build

.PHONY: all check-env dump qemu qemu-el2 debug debug-el2 dtb clean
