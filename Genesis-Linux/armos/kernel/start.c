/*
 * start.c - First C code to run. Reached from boot.S once a stack exists and
 * .bss has been zeroed.
 *
 * docs/guide/m1-boot-flow.html §7 §8
 */

#include "uart.h"

/* Uninitialised, so it lives in .bss. Reading it as 0 is the only evidence
 * boot.S cleared that region - nothing else provides that guarantee here. */
static unsigned long boot_counter;

/* Kept separate so kernel_main has to save x30 before calling it - that is
 * what makes the stack load-bearing. */
static void bump(void)
{
    boot_counter++;
}

void kernel_main(void)
{
    uart_init();
    uart_puts("Hello, AArch64 from EL1\n");

    /* boot_counter is still what 'make debug' checks to prove .bss was
     * cleared, and calling bump() is what keeps the stack load-bearing. */
    while (1) {
        bump();
    }
}
