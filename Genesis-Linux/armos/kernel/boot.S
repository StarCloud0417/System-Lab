/*
 * boot.S - Kernel entry point for the QEMU 'virt' machine.
 *
 * First code the CPU runs after QEMU loads the image. Nothing is set up yet:
 * no stack, no zeroed .bss, no MMU, no C runtime - only x0-x30 and the PC are
 * usable, which is why this stays in assembly until M1.
 *
 * Full walkthrough: docs/guide/m0-build-and-boot.html (§5 boot.S, §7 myths 4-5)
 */

/* "ax" = allocatable + executable. Matched by name from the linker script. */
.section .text.boot, "ax"

.global _start
_start:
    /* xzr reads as zero. Encoding 31 means XZR or SP depending on the form. */
    mov     x0, xzr

halt_loop:
    /*
     * Not 'b .': a halted core and a spinning core look identical from the
     * outside, so 'b .' cannot show that the image actually ran. An
     * incrementing x0 can. Removed in M1, when real boot code takes over.
     */
    add     x0, x0, #1
    b       halt_loop
