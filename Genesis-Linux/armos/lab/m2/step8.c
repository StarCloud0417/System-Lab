/*
 * 階梯 8：TXFF 等待迴圈到底跑了幾圈。
 *
 * 誰會跑我： make step8
 *
 * 連寫 64 個字元，每次進迴圈就計數。教材說 QEMU 上是 0。
 */

#include <stdint.h>

#include "mmio.h"
#include "platform.h"

#define UART_DR     0x00
#define UART_FR     0x18
#define FR_TXFF     (1u << 5)

volatile uint32_t spins;        /* 等待迴圈總共跑了幾圈 */
volatile uint32_t fr_or;        /* 64 次讀到的 FR 全部 OR 起來 */

static void putc_wait(char c)
{
    uint32_t fr;
    while ((fr = mmio_read32(UART0_BASE + UART_FR)) & FR_TXFF) {
        spins++;
    }
    fr_or |= fr;
    mmio_write32(UART0_BASE + UART_DR, (uint32_t)(unsigned char)c);
}

/* 斷點打在這裡：位址由 nm 查，不受程式長度影響。 */
void done(void);
void done(void) { }

void kernel_main(void)
{
    for (int i = 0; i < 64; i++) {
        putc_wait('.');
    }
    putc_wait('\n');
    done();
    while (1) { }
}
