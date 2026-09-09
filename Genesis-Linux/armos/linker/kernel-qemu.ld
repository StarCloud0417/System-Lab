/*
 * kernel-qemu.ld - Linker script for the QEMU 'virt' machine.
 *
 * RAM starts at 0x4000_0000 (from the machine's own device tree - run
 * 'make dtb'); everything below that is MMIO. '-kernel' makes QEMU the ELF
 * loader: it copies each PT_LOAD to the PhysAddr in its program header and
 * begins at the entry point.
 *
 * Full walkthrough: docs/guide/m0-build-and-boot.html §5 (syntax),
 *                   docs/guide/m1-boot-flow.html (stack and .bss)
 */

ENTRY(_start)                       /* fills e_entry in the ELF header */

STACK_SIZE = 64K;                   /* boot stack; revisited in M7 */

SECTIONS
{
    . = 0x40000000;                 /* location counter: the address being handed out */

    .text : {
        /*
         * .text.boot first and separate, so _start lands exactly at the load
         * address once there is more than one input file. Section names are
         * matched as plain strings - a typo here is silent, not an error.
         */
        *(.text.boot)
        *(.text .text.*)
    }

    /*
     * M2's first string constant created .rodata. Naming it here keeps it out
     * of ld's orphan-placement heuristic, which is what decides where an
     * unmentioned section lands - and that decision is not ours to inherit.
     */
    .rodata : {
        *(.rodata .rodata.*)
    }

    /*
     * No .data yet - nothing defines an initialised writable global.
     *
     * Both symbols live inside the braces, so nothing can be placed between
     * __bss_start and the section it names. Measured on binutils 2.38: with
     * the symbol outside AND no preceding ALIGN, .eh_frame lands between them
     * and the zeroing loop wipes it. Keeping the ALIGN happens to prevent
     * that, but by accident - it is an alignment directive, not a guard.
     * ALIGN(16) at both ends is what lets the loop store two registers at a
     * time with no leftover tail.
     */
    .bss : {
        . = ALIGN(16);
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(16);
        __bss_end = .;
    }

    /*
     * Grows downwards from __stack_top, kept 16-byte aligned because the
     * architecture requires it (SCTLR_EL1.SA resets to 1). QEMU's TCG does
     * not enforce it - measured, a misaligned SP works there. This alignment
     * is for M9's real hardware. Kept out of .bss so the zeroing
     * loop has 64K less to walk - not for correctness, since the loop itself
     * uses no stack and nothing has been pushed yet.
     */
    . = ALIGN(16);
    .stack : {
        . += STACK_SIZE;
        __stack_top = .;
    }
}
