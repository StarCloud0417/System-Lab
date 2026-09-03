/*
 * start.c - First C code to run. Reached from boot.S once a stack exists and
 * .bss has been zeroed.
 *
 * docs/guide/m1-boot-flow.html §7 §8
 */

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
    /* No UART until M2, so liveness is still a changing value. */
    while (1) {
        bump();
    }
}
