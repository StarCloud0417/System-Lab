/*
 * 階梯 9：先問層級，再決定要不要降。指令與 kernel/boot.S 完全相同。
 *
 * 誰會跑我： make step9       -M virt
 *           make step9-el2   -M virt,virtualization=on
 *
 * 兩者印出來的三個值應該一字不差 —— 那就是 M1 的驗收標準。
 */

.section .text.boot, "ax"

.global _start
_start:
    mrs     x9, CurrentEL           /* reads as EL * 4 */
    cmp     x9, #(1 << 2)           /* EL1 */
    b.eq    el1_entry

    mov     x9, #(1 << 31)          /* HCR_EL2.RW: EL1 is AArch64 */
    msr     hcr_el2, x9
    mov     x9, #0x3c5              /* SPSR_EL2: EL1h, DAIF masked */
    msr     spsr_el2, x9
    adr     x9, el1_entry           /* ELR_EL2: where eret lands */
    msr     elr_el2, x9
    eret

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

    /* kernel_main is not expected to return; park the core if it does.
     * wfe puts the core to sleep instead of spinning hot - that is the
     * only difference from the plain 'b here' used in steps 1-8. */
halt_loop:
    wfe
    b       halt_loop
