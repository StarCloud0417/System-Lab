/*
 * boot.S - Kernel entry point.
 *
 * Firmware may hand us EL2 (Raspberry Pi, QEMU with virtualization=on) or
 * EL1 (plain -M virt). Normalise that to "always EL1", give C a stack and a
 * zeroed .bss, then hand over.
 *
 * docs/guide/m1-boot-flow.html §4-§8 — why, what each value means, line by line
 */

.section .text.boot, "ax"

.global _start
_start:
    /* Scratch in x9/x10: x0-x3 carry the boot protocol arguments. */
    mrs     x9, CurrentEL           /* reads as EL * 4 */
    cmp     x9, #(1 << 2)           /* EL1 */
    b.eq    el1_entry

    mov     x9, #(1 << 31)          /* HCR_EL2.RW: EL1 is AArch64 */
    msr     hcr_el2, x9
    mov     x9, #0x3c5              /* SPSR_EL2: EL1h, DAIF masked */
    msr     spsr_el2, x9
    adr     x9, el1_entry           /* ELR_EL2: where eret lands */
    msr     elr_el2, x9
    eret                            /* the only way down a level */

el1_entry:
    /* A stack must exist before any call: the callee writes below SP first. */
    ldr     x9, =__stack_top
    mov     sp, x9

    /* C assumes uninitialised globals read as zero; nobody else provides that.
     * The linker aligns both ends to 16, so stp needs no tail case. */
    ldr     x9, =__bss_start
    ldr     x10, =__bss_end
bss_zero:
    cmp     x9, x10
    b.hs    enter_c                 /* unsigned: addresses have no sign */
    stp     xzr, xzr, [x9], #16     /* post-index: write, then advance */
    b       bss_zero

enter_c:
    bl      kernel_main

    /* kernel_main is not expected to return; park the core if it does. */
halt_loop:
    wfe
    b       halt_loop
