/*
 * kernel-qemu.ld - Linker script for the QEMU 'virt' machine.
 *
 * RAM starts at 0x4000_0000 (from the machine's own device tree - run
 * 'make dtb'); everything below that is MMIO. '-kernel' makes QEMU the ELF
 * loader: it copies each PT_LOAD to the PhysAddr in its program header and
 * begins at the entry point.
 *
 * Full walkthrough: docs/guide/m0-build-and-boot.html (§5 syntax, §7 myths 1-2)
 */

ENTRY(_start)                       /* fills e_entry in the ELF header */

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
     * No .rodata/.data/.bss yet: boot.S defines no data. They arrive in M1
     * together with __bss_start/__bss_end and the code that zeroes them.
     */
}
