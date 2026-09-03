/*
 * 階梯 7：從 EL2 降到 EL1。還沒判斷自己在哪一層。
 *
 * 誰會跑我： make step7   -M virt,virtualization=on
 *           make step8   -M virt
 *
 * 沒有 step8.S 這個檔案。階梯 8 跑的就是這一份，只換 QEMU 機器參數。
 * 一般開機直接就在 EL1，下面第一條 msr hcr_el2 就會炸 —— 那就是「沒先問
 * 自己在哪一層」的代價，也是階梯 9 要修的東西。
 */

.section .text.boot, "ax"

.global _start
_start:
    mov     x9, #(1 << 31)          /* HCR_EL2.RW: EL1 is AArch64 */
    msr     hcr_el2, x9
    mov     x9, #0x3c5              /* SPSR_EL2: EL1h, DAIF masked */
    msr     spsr_el2, x9
    adr     x9, el1_entry           /* ELR_EL2: where eret lands */
    msr     elr_el2, x9
    eret                            /* the only way down a level */

el1_entry:
    ldr     x9, =__stack_top
    mov     sp, x9

    ldr     x9, =__bss_start
    ldr     x10, =__bss_end
bss_zero:
    cmp     x9, x10
    b.hs    enter_c
    stp     xzr, xzr, [x9], #16
    b       bss_zero

enter_c:
    bl      kernel_main

here:
    b       here
