#!/bin/bash
#
# run.sh <step> - 編譯一階、跑起來、把該看的東西印出來。
#
# 位址一律用 nm 查，不寫死。由 Makefile 呼叫，也可以直接 ./run.sh step5
#
set -u
set -o pipefail

LAB="$(cd "$(dirname "$0")" && pwd)"
STEP="${1:-}"
[ -n "$STEP" ] || { echo "用法: ./run.sh step1|...|step9"; exit 2; }

CROSS="${CROSS:-aarch64-linux-gnu-}"
QEMU="${QEMU:-qemu-system-aarch64}"
GDB="${GDB:-gdb-multiarch}"
CC="$CROSS"gcc
NM="$CROSS"nm
OBJDUMP="$CROSS"objdump

WARN="-Wall -Wextra -Werror"
LDFLAGS="-ffreestanding -nostdlib -static -I$LAB -Wl,-T,$LAB/kernel-qemu.ld -Wl,--build-id=none"

mkdir -p "$LAB/build"
B=$LAB/build

# 編譯一份核心。用法: build <輸出名> <opt> <來源...>
build() {
    local out=$1 opt=$2; shift 2
    "$CC" $WARN $opt $LDFLAGS -o "$B/$out.elf" "$@" || exit 1
}

# 在 QEMU 跑，把序列埠寫到檔案。用法: serial <elf> <秒>
serial() {
    pkill -x qemu-system-aar 2>/dev/null || true; sleep 0.5
    rm -f "$B/serial.log"
    timeout "${2:-3}" "$QEMU" -M virt -cpu cortex-a72 -display none \
        -serial file:"$B/serial.log" -kernel "$1" >/dev/null 2>&1
    pkill -x qemu-system-aar 2>/dev/null || true
}

# 接 GDB 讀值。用法: peek <elf> <gdb 指令...>
peek() {
    local elf=$1; shift
    pkill -x qemu-system-aar 2>/dev/null || true; sleep 0.5
    if ss -ltn 2>/dev/null | grep -q ':1234 '; then
        echo "port 1234 被佔用。清場：pkill -x qemu-system-aar"; exit 1
    fi
    "$QEMU" -M virt -cpu cortex-a72 -display none -serial none \
        -kernel "$elf" -S -s 2>/dev/null &
    local qpid=$!
    for _ in $(seq 20); do
        ss -ltn 2>/dev/null | grep -q ':1234 ' && break
        kill -0 $qpid 2>/dev/null || { echo "QEMU 沒起來"; exit 1; }
        sleep 0.25
    done
    local args=(); local c
    for c in "$@"; do args+=(-ex "$c"); done
    timeout 60 "$GDB" -q -batch "$elf" -ex 'target remote :1234' "${args[@]}" \
        | grep -v '^\[Inferior'
    local rc=${PIPESTATUS[0]}
    kill $qpid 2>/dev/null; wait $qpid 2>/dev/null
    [ "$rc" -eq 0 ] || { echo "!! GDB 沒跑完（結束碼 $rc）"; exit "$rc"; }
}

# 產生一份「拿掉 volatile」的對照樹。
#
# 陷阱：#include "mmio.h" 會先找【原始檔自己的目錄】，-I 排在後面。
# 所以光加 -I 指向改過的標頭沒有用 —— 原始檔也必須複製過去，
# 否則它會繼續用隔壁那份有 volatile 的，實驗會安靜地測到錯的東西。
novol() {
    mkdir -p "$B/novol"
    sed 's/volatile uint32_t \*/uint32_t */g' "$LAB/mmio.h" > "$B/novol/mmio.h"
    cp "$LAB/platform.h" "$B/novol/"
    cp "$LAB/step45.c"   "$B/novol/"
}

hdr() { echo "=============================================================="; \
        echo " $STEP —— $1"; echo "=============================================================="; }

case "$STEP" in

step1)
    hdr "完全不初始化，直接往 DR 寫 —— 會有輸出嗎？"
    build step1 "" "$LAB/step1.S"
    serial "$B/step1.elf"
    echo "序列埠收到："; xxd "$B/serial.log"
    echo
    echo "→ 有輸出。所以 QEMU 上「初始化」不是輸出的必要條件。"
    echo "  那開機時那些設定暫存器長什麼樣？下一階。"
    ;;

step2)
    hdr "開機時 PL011 的六個暫存器"
    build step2 "" "$LAB/step2.S"
    peek "$B/step2.elf" 'break here' 'continue' \
        'printf "\nCR     = "' 'p/x $x21' \
        'printf "UARTEN = "' 'p $x26' \
        'printf "IBRD   = "' 'p/x $x22' \
        'printf "FBRD   = "' 'p/x $x23' \
        'printf "LCR_H  = "' 'p/x $x24' \
        'printf "FR     = "' 'p/x $x25'
    echo
    echo "→ UARTEN = 0（UART「沒啟用」）、鮑率沒設、字元長度沒設。"
    echo "  階梯 1 就是在這個狀態下把字送出去的。"
    echo "  所以 uart_init() 是為了誰？答案在階梯 9，先看 volatile。"
    ;;

step3)
    hdr "用 C 寫最小的 putc：沒 init、沒 volatile、沒等待迴圈"
    build step3 "" "$LAB/boot.S" "$LAB/step3.c"
    serial "$B/step3.elf"
    echo "序列埠收到："; cat "$B/serial.log"; echo
    echo "→ 三樣都沒有，照樣能動。那 volatile 到底防了什麼？下一階。"
    ;;

step4)
    hdr "volatile 在 -O0 下有差別嗎"
    novol
    build v_o0   "-O0" "$LAB/boot.S" "$LAB/step45.c"
    "$CC" $WARN -O0 -ffreestanding -nostdlib -static \
        -Wl,-T,"$LAB/kernel-qemu.ld" -Wl,--build-id=none \
        -o "$B/n_o0.elf" "$LAB/boot.S" "$B/novol/step45.c" || exit 1
    for e in v_o0 n_o0; do
        printf "  %-22s uart_init 裡的 str 有幾條: " \
            "$([ $e = v_o0 ] && echo '有 volatile' || echo '無 volatile')"
        "$OBJDUMP" -d "$B/$e.elf" | sed -n '/<uart_init>:/,/^$/p' | grep -cE '\sstr\s'
    done
    echo
    echo "  （-O0 不展開 inline，str 藏在 mmio_write32 裡，所以兩邊都是 1）"
    echo "→ -O0 下加不加 volatile，產出一模一樣。看不出差別。"
    echo "  換 -O2 就看得出來了 —— 下一階。"
    ;;

step5)
    hdr "volatile 在 -O2 下救了哪一條指令   ★ 這一階是重點"
    novol
    build v_o2 "-O2" "$LAB/boot.S" "$LAB/step45.c"
    "$CC" $WARN -O2 -ffreestanding -nostdlib -static \
        -Wl,-T,"$LAB/kernel-qemu.ld" -Wl,--build-id=none \
        -o "$B/n_o2.elf" "$LAB/boot.S" "$B/novol/step45.c" || exit 1
    for e in v_o2 n_o2; do
        printf "  %-22s str 有幾條: " \
            "$([ $e = v_o2 ] && echo '-O2 有 volatile' || echo '-O2 無 volatile')"
        "$OBJDUMP" -d "$B/$e.elf" | sed -n '/<uart_init>:/,/^$/p' | grep -cE '\sstr\s'
    done
    echo
    echo "--- -O2 無 volatile 的 uart_init ---"
    "$OBJDUMP" -d "$B/n_o2.elf" | sed -n '/<uart_init>:/,/^$/p' | grep -E 'str|ret'
    echo
    echo "  （對照組是把原始檔也複製到改過的標頭旁邊才建的 ——"
    echo "    #include \"mmio.h\" 會先找原始檔自己的目錄，光加 -I 沒有用。）"
    echo
    echo "→ 少的那一條是 CR = 0（「先關掉」）。編譯器看到 CR 被寫兩次，"
    echo "  把第一次當成死存取刪掉了 —— 而那正是註解裡說要保護 in-flight 字元的那行。"
    echo "  它在 QEMU 上照樣印得出來，完全隱形。"
    ;;

step6)
    hdr "鮑率：捨去 vs 四捨五入，在哪個時脈上分岔"
    build step6 "" "$LAB/boot.S" "$LAB/step6.c"
    sym() { "$NM" "$B/step6.elf" | awk -v n="$1" '$3==n {print "0x"$1}'; }
    peek "$B/step6.elf" 'break done' 'continue' \
        'printf "\n                      IBRD  FBRD\n"' \
        "printf \"  24 MHz  捨去      %d     %d\n\", *(unsigned int *)$(sym q_floor_ibrd), *(unsigned int *)$(sym q_floor_fbrd)" \
        "printf \"          四捨五入  %d     %d\n\", *(unsigned int *)$(sym q_round_ibrd), *(unsigned int *)$(sym q_round_fbrd)" \
        "printf \"  48 MHz  捨去      %d     %d\n\", *(unsigned int *)$(sym p_floor_ibrd), *(unsigned int *)$(sym p_floor_fbrd)" \
        "printf \"          四捨五入  %d     %d\n\", *(unsigned int *)$(sym p_round_ibrd), *(unsigned int *)$(sym p_round_fbrd)"
    echo
    echo "→ 24 MHz 兩者相同，48 MHz 的 FBRD 差一格。"
    echo "  第一版用的是捨去，而唯一能驗證的平台剛好是兩者一致的那個。"
    ;;

step7)
    hdr "CR/LF 轉換放在 uart_puts 裡的後果"
    build step7 "" "$LAB/boot.S" "$LAB/step7.c"
    serial "$B/step7.elf"
    echo "序列埠收到："; xxd "$B/serial.log"
    echo
    echo "→ puts(\"A\\n\") 補了 0d，putc('B') + putc('\\n') 沒有。"
    echo "  printf 是逐字元呼叫 putc 的 —— 下一包就會撞到。"
    echo "  所以正式版把轉換搬進 uart_putc，讓它成為唯一出口。"
    ;;

step8)
    hdr "TXFF 等待迴圈跑了幾圈"
    build step8 "" "$LAB/boot.S" "$LAB/step8.c"
    sym() { "$NM" "$B/step8.elf" | awk -v n="$1" '$3==n {print "0x"$1}'; }
    peek "$B/step8.elf" 'break done' 'continue' \
        "printf \"\n  連寫 65 個字元，等待迴圈跑了 %d 圈\n\", *(unsigned int *)$(sym spins)" \
        "printf \"  65 次讀到的 FR 全部 OR 起來 = 0x%x\n\", *(unsigned int *)$(sym fr_or)"
    echo
    echo "→ 0 圈。QEMU 瞬間排空佇列，TXFF 一次都沒被拉起來。"
    echo "  這個迴圈是為了真硬體 16 深的 FIFO 而寫的，在這裡拿掉毫無差別。"
    ;;

step9)
    hdr "完整版 —— 與 drivers/uart/pl011.c 相同"
    build step9 "" "$LAB/boot.S" "$LAB/step9.c"
    serial "$B/step9.elf"
    echo "序列埠收到："; xxd "$B/serial.log" | tail -3
    echo
    peek "$B/step9.elf" 'break uart_puts' 'continue' \
        'printf "\n  init 之後 CR    = "' 'p/x *(unsigned int *)0x09000030' \
        'printf "            IBRD  = "' 'p/x *(unsigned int *)0x09000024' \
        'printf "            FBRD  = "' 'p/x *(unsigned int *)0x09000028' \
        'printf "            LCR_H = "' 'p/x *(unsigned int *)0x0900002c'
    echo
    echo "→ CR = 0x101（UARTEN|TXE，沒有 RXE —— 現在沒人讀）"
    echo "  IBRD/FBRD 是程式從 platform.h 的 24 MHz 算出來的，不是常數。"
    ;;

*) echo "不認得的階梯: $STEP"; exit 2 ;;
esac
echo
