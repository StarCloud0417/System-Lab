/*
 * start.c - the C side of the ladder. Frozen snapshot of what M1's
 * kernel/start.c looked like; the lab does not track later milestones.
 */

static unsigned long boot_counter;

static void bump(void)
{
    boot_counter++;
}

void kernel_main(void)
{
    while (1) {
        bump();
    }
}
