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
     * No .rodata or .data yet - nothing defines any; they arrive in M2.
     *
     * Both symbols live inside the braces: outside, ld is free to place an
     * orphan section (.eh_frame does land here) between __bss_start and .bss,
     * and the zeroing loop would wipe it. ALIGN(16) at both ends lets that
     * loop store two registers at a time with no leftover tail.
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
     * Grows downwards from __stack_top, which must be 16-byte aligned: the
     * hardware faults on a misaligned SP. Kept out of .bss so the zeroing
     * loop has 64K less to walk - not for correctness, since the loop itself
     * uses no stack and nothing has been pushed yet.
     */
    . = ALIGN(16);
    .stack : {
        . += STACK_SIZE;
        __stack_top = .;
    }
}
