/*
 * platform.h - Addresses that change when the board changes.
 *
 * QEMU 'virt'. Every value here came from the machine's own device tree
 * ('make dtb'), not from a datasheet.
 *
 * M9 adds a second file for the Raspberry Pi 4, where the same PL011 sits at
 * 0xFE20_1000. The driver itself needs no editing - but the board does need
 * work that lives elsewhere: GPIO 14/15 must be muxed to ALT0 before the UART
 * reaches a pin, and the Pi's PL011 clock is whatever firmware set, not a
 * fixed number in a device tree.
 */

#ifndef PLATFORM_H
#define PLATFORM_H

#define UART0_BASE      0x09000000UL     /* pl011@9000000 */
#define UART0_CLK_HZ    24000000UL       /* apb-pclk, "clk24mhz" */
#define UART0_BAUD      115200UL

#endif /* PLATFORM_H */
