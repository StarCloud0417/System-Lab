/*
 * boot.S - Kernel entry point.
 *
 * Firmware may hand us EL2 (Raspberry Pi, QEMU with virtualization=on) or
 * EL1 (plain -M virt). Normalise that to "always EL1" before anything else.
 *
 * docs/guide/m1-boot-flow.html §4 §5 §6 — why, what each value means, line by line
 */

.section .text.boot, "ax"

.global _start
_start:
    /* Scratch in x9/x10: x0-x3 carry the boot protocol arguments. */
    mrs     x9, CurrentEL           /* reads as EL * 4 */
    cmp     x9, #(1 << 2)
    b.eq    el1_entry

    mov     x9, #(1 << 31)          /* HCR_EL2.RW: EL1 is AArch64 */
    msr     hcr_el2, x9
    mov     x9, #0x3c5              /* SPSR_EL2: EL1h, DAIF masked */
    msr     spsr_el2, x9
    adr     x9, el1_entry
    msr     elr_el2, x9
    eret                            /* the only way down a level */

el1_entry:
    /* Proof of life until the UART arrives in M2; a spinning core and a
     * halted one look identical from outside. */
    mov     x10, xzr
halt_loop:
    add     x10, x10, #1
    b       halt_loop
