/*
 * mmio.h - 快照，跟 include/mmio.h 相同。
 *
 * 階梯 4、5 會拿掉這裡的 volatile 做對照。
 */

#ifndef MMIO_H
#define MMIO_H

#include <stdint.h>

static inline void mmio_write32(uintptr_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

static inline uint32_t mmio_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

#endif
