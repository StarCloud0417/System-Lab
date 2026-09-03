#!/bin/bash
#
# run.sh <step> - 編譯一階、在 QEMU 跑、用 GDB 停在該看的地方。
#
# 位址每一階都不同（程式長度變了），所以一律用 nm 查，不寫死。
# 由 Makefile 呼叫；也可以直接跑：./run.sh step5
#
set -u
set -o pipefail

LAB="$(cd "$(dirname "$0")" && pwd)"
STEP="${1:-}"
[ -n "$STEP" ] || { echo "用法: ./run.sh step1|step2|...|step9|vbar"; exit 2; }

CROSS="${CROSS:-aarch64-linux-gnu-}"
QEMU="${QEMU:-qemu-system-aarch64}"
GDB="${GDB:-gdb-multiarch}"

# 哪一階用哪個 .S、哪種機器、要不要先弄髒 .bss
SRC=$STEP.S ; MACHINE=virt ; POISON=no ; TITLE=""
case "$STEP" in
step1) TITLE="最小核心 —— CPU 有跑到我的程式嗎" ;;
step2) TITLE="我在哪一層 —— CurrentEL" ;;
step3) TITLE="直接呼叫 C —— 沒有堆疊，會炸" ;;
step4) TITLE="給它堆疊 —— 活了，但 .bss 還沒清"; POISON=yes ;;
step5) TITLE="清 .bss —— 開機前先弄髒，實驗才可能失敗"; POISON=yes ;;
step6) TITLE="同一份 step5，改用 EL2 開機 —— 不會炸，但層級錯了"
       SRC=step5.S ; MACHINE=virt,virtualization=on ; POISON=yes ;;
step7) TITLE="降到 EL1 —— 盯著 eret 那一刻"
       MACHINE=virt,virtualization=on ; POISON=yes ;;
step8) TITLE="同一份 step7，改用一般開機 —— 在 EL1 碰 EL2 暫存器"
       SRC=step7.S ;;
step9) TITLE="先問層級再決定 —— 這就是 kernel/boot.S"; POISON=yes ;;
step9-el2) TITLE="同一個 step9，換 EL2 開機 —— 三個數字應該一字不差"
       SRC=step9.S ; MACHINE=virt,virtualization=on ; POISON=yes ;;
vbar)  TITLE="VBAR_EL1 和 VBAR_EL2 是兩顆不同的暫存器"
       MACHINE=virt,virtualization=on ;;
norw)  TITLE="第三種 0x200 —— eret 跑了，但層級沒換"
       MACHINE=virt,virtualization=on ;;
*) echo "不認得的階梯: $STEP"; exit 2 ;;
esac

# step1/step2/vbar 沒有呼叫 C，不要連 start.c 進去
SRCS="$LAB/$SRC"
case "$STEP" in step1|step2|vbar) ;; *) SRCS="$SRCS $LAB/start.c" ;; esac

ELF=$LAB/build/$STEP.elf
mkdir -p "$LAB/build"

echo "=============================================================="
echo " $STEP —— $TITLE"
echo "   原始碼 $SRC   機器 -M $MACHINE"
echo "=============================================================="

"$CROSS"gcc -Wall -Wextra -Werror -ffreestanding -nostdlib -static \
    -Wl,-T,"$LAB/kernel-qemu.ld" -Wl,--build-id=none -o "$ELF" $SRCS || exit 1  # $SRCS 故意不加引號：它是多個檔名

sym() { "$CROSS"nm "$ELF" | awk -v n="$1" '$3==n {print "0x"$1}'; }
KMAIN=$(sym kernel_main)
BSS=$(sym __bss_start)
ENTRY=$(sym el1_entry)

# 每一階要看什麼，就在這裡決定
G=()
g() { G+=(-ex "$1"); }
case "$STEP" in
step1)
    g 'printf "\n-- 開機，一條指令都還沒跑 --\n"'
    g 'printf "PC = "' ; g 'p/x $pc' ; g 'printf "x9 = "' ; g 'p/x $x9'
    g 'x/3i $pc'
    g 'stepi'
    g 'printf "\n-- 走完 mov --\n"'
    g 'printf "PC = "' ; g 'p/x $pc' ; g 'printf "x9 = "' ; g 'p/x $x9'
    g 'stepi'
    g 'printf "\n-- 走完 b（原地打轉，PC 不會動）--\n"'
    g 'printf "PC = "' ; g 'p/x $pc'
    ;;
step2)
    g 'stepi'
    g 'printf "\nCurrentEL = "' ; g 'p/x $x9'
    g 'printf "（0x4 = EL1、0x8 = EL2；整個值就是 EL 編號 x 4）\n"'
    ;;
step3)
    g "break *$KMAIN" ; g 'continue'
    g 'printf "\n-- 停在 kernel_main 第一條 --\n"'
    g 'printf "SP = "' ; g 'p/x $sp'
    g 'x/1i $pc'
    g 'stepi'
    g 'printf "\n-- 執行完那條 stp --\n"'
    g 'printf "PC = "' ; g 'p/x $pc'
    g 'printf "VBAR = "' ; g 'p/x $VBAR'
    g 'printf "ESR_EL1 = "' ; g 'p/x $ESR_EL1'
    g 'printf "  EC    = "' ; g 'p/x $ESR_EL1 >> 26'
    g 'printf "FAR_EL1 = "' ; g 'p/x $FAR_EL1'
    g 'printf "（EC = 例外種類，0x25 = Data Abort。FAR = 出事的位址，0xfff...ff0 就是 sp-16）\n"'
    g 'x/2i $pc'
    g 'printf "\n0x200 = VBAR(0) + 0x200，同層同步例外的入口。那裡是 QEMU 的 device tree：\n"'
    g 'x/2xw 0x0' ; g 'x/s 0x200'
    ;;
step4)
    g 'printf "\nSP 重置時          = "' ; g 'p/x $sp'
    g "printf \"開機前 boot_counter = \"" ; g "p/x *(unsigned long *)$BSS"
    g "break *$KMAIN" ; g 'continue'
    g 'printf "\n-- 進 kernel_main --\n"'
    g 'printf "SP                 = "' ; g 'p/x $sp'
    g 'stepi'
    g 'printf "SP 過了 prologue    = "' ; g 'p/x $sp'
    g 'printf "（差 16 = stp x29,x30,[sp,#-16]! 推下去的）\n"'
    g "printf \"boot_counter       = \"" ; g "p/x *(unsigned long *)$BSS"
    g 'printf "\nC 跑起來了，但那個髒值原封不動 —— 沒有人清 .bss。這就是階梯 5。\n"'
    ;;
step5|step6)
    g "printf \"\\n開機前 boot_counter = \"" ; g "p/x *(unsigned long *)$BSS"
    g "break *$KMAIN" ; g 'continue'
    g 'printf "\n-- 進 kernel_main --\n"'
    g 'printf "SP           = "' ; g 'p/x $sp'
    g 'printf "EL           = "' ; g 'p ($cpsr >> 2) & 3'
    g "printf \"boot_counter = \"" ; g "p/x *(unsigned long *)$BSS"
    g 'printf "cpsr         = "' ; g 'p/x $cpsr'
    ;;
step9|step9-el2)
    g "printf \"\\n開機前 boot_counter = \"" ; g "p/x *(unsigned long *)$BSS"
    g "break *$KMAIN" ; g 'continue'
    g 'printf "\n-- 進 kernel_main（第一條指令，序言還沒跑）--\n"'
    g 'printf "SP           = "' ; g 'p/x $sp'
    g 'printf "EL           = "' ; g 'p ($cpsr >> 2) & 3'
    g "printf \"boot_counter = \"" ; g "p/x *(unsigned long *)$BSS"
    g 'printf "cpsr         = "' ; g 'p/x $cpsr'
    g 'stepi'
    g 'printf "\n-- 走完序言 stp x29,x30,[sp,#-16]! --\n"'
    g 'printf "SP           = "' ; g 'p/x $sp'
    g 'printf "（repo 的 make debug 用 break kernel_main，會跳過序言，所以印的是這個值）\n"'
    ;;
step7)
    g 'printf "\neret 之前 EL = "' ; g 'p ($cpsr >> 2) & 3'
    g "break *$ENTRY" ; g 'continue'
    g 'printf "eret 之後 EL = "' ; g 'p ($cpsr >> 2) & 3'
    g "break *$KMAIN" ; g 'continue'
    g 'printf "\n-- 進 kernel_main --\n"'
    g 'printf "SP           = "' ; g 'p/x $sp'
    g "printf \"boot_counter = \"" ; g "p/x *(unsigned long *)$BSS"
    g 'printf "cpsr         = "' ; g 'p/x $cpsr'
    g 'printf "（低 12 位 0x3c5 就是我們寫進 SPSR_EL2 的值）\n"'
    ;;
step8)
    g 'printf "\n開機時 EL = "' ; g 'p ($cpsr >> 2) & 3'
    g 'stepi 2'
    g 'printf "\n-- 執行完 msr hcr_el2 --\n"'
    g 'printf "PC = "' ; g 'p/x $pc'
    g 'printf "EL = "' ; g 'p ($cpsr >> 2) & 3'
    g 'printf "ESR_EL1 = "' ; g 'p/x $ESR_EL1'
    g 'printf "  EC    = "' ; g 'p/x $ESR_EL1 >> 26'
    g 'x/2i $pc'
    g 'printf "\nEL1 碰不到 EL2 的暫存器。eret 根本沒機會跑。\n"'
    g 'printf "跟 step3 比：pc 和 EL 一模一樣，分岔的是 EC —— 0x0 (Unknown) vs 0x25 (Data Abort)。\n"'
    ;;
norw)
    g 'printf "\neret 之前  EL = "' ; g 'p ($cpsr >> 2) & 3'
    g "break *$ENTRY" ; g 'continue'
    g 'printf "\n-- 停在 el1_entry（eret 說要來這裡）--\n"'
    g 'printf "PC        = "' ; g 'p/x $pc'
    g 'printf "EL        = "' ; g 'p ($cpsr >> 2) & 3'
    g 'printf "PSTATE.IL = "' ; g 'p ($cpsr >> 20) & 1'
    g 'printf "（EL 還是 2 —— eret 執行了，但硬體拒絕換層，改把 IL 設起來）\n"'
    g 'delete' ; g 'stepi'
    g 'printf "\n-- 再走一條指令 --\n"'
    g 'printf "PC        = "' ; g 'p/x $pc'
    g 'printf "EL        = "' ; g 'p ($cpsr >> 2) & 3'
    g 'printf "\n跟 step3 / step8 比：pc 都是 0x200，但這次 EL = 2。\n"'
    ;;
vbar)
    g 'stepi 4'
    g 'printf "\nEL       = "' ; g 'p ($cpsr >> 2) & 3'
    g 'printf "VBAR_EL1 = "' ; g 'p/x $x11'
    g 'printf "VBAR_EL2 = "' ; g 'p/x $x12'
    g 'printf "（只寫了 EL1 那顆，EL2 那顆完全沒動）\n"'
    ;;
esac

if ss -ltn 2>/dev/null | grep -q ':1234 '; then
    echo "port 1234 已被佔用。清場：pkill -x qemu-system-aar"
    echo "（行程名被截成 15 字元；用全名比對不到，加 -f 又會殺到自己的 shell）"
    exit 1
fi

POISON_ARG=()
[ "$POISON" = yes ] && POISON_ARG=(-device "loader,addr=$BSS,data=0xcafe1234,data-len=4")

"$QEMU" -M "$MACHINE" -cpu cortex-a72 -display none -serial none \
        -kernel "$ELF" -S -s "${POISON_ARG[@]}" 2>/dev/null &
QPID=$!

# 等 gdbstub 真的開好。不等就跑 GDB 的話，它會改從 ELF 檔靜態讀，
# 印出一堆「看起來像對的」值 —— 那比直接失敗危險得多。
for _ in $(seq 20); do
    ss -ltn 2>/dev/null | grep -q ':1234 ' && break
    kill -0 $QPID 2>/dev/null || { echo "QEMU 沒起來（$QEMU）"; exit 1; }
    sleep 0.25
done
if ! ss -ltn 2>/dev/null | grep -q ':1234 '; then
    echo "等不到 QEMU 的 gdbstub（port 1234）"; kill $QPID 2>/dev/null; exit 1
fi
timeout 60 "$GDB" -q -batch "$ELF" -ex 'target remote :1234' "${G[@]}" \
    | grep -v '^\[Inferior'
RC=${PIPESTATUS[0]}         # 要 GDB/timeout 的結束碼，不是 grep 的
kill $QPID 2>/dev/null
wait $QPID 2>/dev/null
echo
[ "$RC" -eq 0 ] || echo "!! 這一階沒有正常跑完（結束碼 $RC）"
exit "$RC"
