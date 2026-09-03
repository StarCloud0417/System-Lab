/*
 * 附錄，不屬於九階：VBAR_EL1 和 VBAR_EL2 是兩顆不同的暫存器。
 *
 * 誰會跑我： make vbar   -M virt,virtualization=on
 *
 * 建議在階梯 6 卡住「EL2 權限更高，為什麼還算錯」的時候跑。
 */

.section .text.boot, "ax"

.global _start
_start:
    mov     x9, #0x1000
    msr     vbar_el1, x9            /* 只寫 EL1 那顆 */
    mrs     x11, vbar_el1
    mrs     x12, vbar_el2           /* 有跟著變嗎？ */
here:
    b       here
