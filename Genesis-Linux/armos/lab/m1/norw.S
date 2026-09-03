/*
 * 附錄，不屬於九階：第三種 0x200。
 *
 * 誰會跑我： make norw   -M virt,virtualization=on
 *
 * 就是 step7.S 拿掉 HCR_EL2 那兩行。HCR_EL2.RW 重置後是 0（EL1 用 32 位元），
 * 而 SPSR_EL2 的 M[4]=0 要求 64 位元 —— 兩邊打架，叫 illegal exception return。
 * 硬體的處理是：不換層、把 PSTATE.IL 設起來，下一次取指令才 trap。
 *
 * 這是三種 0x200 裡唯一「eret 執行了卻沒換層」的那種，也是唯一當時 EL=2 的。
 */

.section .text.boot, "ax"

.global _start
_start:
    /* 這裡少了 mov x9, #(1 << 31) / msr hcr_el2, x9 */
    mov     x9, #0x3c5              /* SPSR_EL2: EL1h, DAIF masked */
    msr     spsr_el2, x9
    adr     x9, el1_entry
    msr     elr_el2, x9
    eret

el1_entry:
    ldr     x9, =__stack_top
    mov     sp, x9
    bl      kernel_main

halt_loop:
    wfe
    b       halt_loop
