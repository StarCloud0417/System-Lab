/*
 * mmio.h - Memory-mapped I/O accessors.
 *
 * Every peripheral register access in this kernel goes through here. Doing it
 * by hand invites forgetting volatile, and that failure is silent.
 *
 * docs/guide/m2-uart.html
 */

#ifndef MMIO_H
#define MMIO_H

#include <stdint.h>

/* volatile: each access counts. The compiler may not merge, drop or reorder
 * them - a peripheral register is not memory. */
static inline void mmio_write32(uintptr_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

static inline uint32_t mmio_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

#endif /* MMIO_H */
