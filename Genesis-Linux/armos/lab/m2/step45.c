/*
 * 階梯 4、5 共用：跟 drivers/uart/pl011.c 同一個形狀的驅動。
 *
 * 誰會跑我： make step4   -O0，比對有沒有 volatile
 *           make step5   -O2，比對有沒有 volatile   ★ 這一階是重點
 *
 * 重點在 uart_init() 第一行的 CR = 0（「先關掉」）。它跟最後一行寫同一個位址，
 * 所以在編譯器眼中可能是一次「死存取」—— 除非那個位址是 volatile。
 *
 * 注意 uart_putc / uart_puts 也在這個檔案裡，不是裝飾。
 * 拿掉它們，同樣的 uart_init() 在 -O2 下就不會被刪 —— 見階梯 5 的輸出。
 */

#include <stdint.h>

#include "mmio.h"
#include "platform.h"

#define UART_DR     0x00
#define UART_FR     0x18
#define UART_IBRD   0x24
#define UART_FBRD   0x28
#define UART_LCR_H  0x2c
#define UART_CR     0x30
#define FR_TXFF     (1u << 5)

void uart_init(void);
void uart_init(void)
{
    mmio_write32(UART0_BASE + UART_CR, 0);          /* 先關掉 */

    uint32_t div64 = (uint32_t)((UART0_CLK_HZ * 8UL / UART0_BAUD + 1UL) / 2UL);
    mmio_write32(UART0_BASE + UART_IBRD, div64 / 64u);
    mmio_write32(UART0_BASE + UART_FBRD, div64 % 64u);
    mmio_write32(UART0_BASE + UART_LCR_H, (1u << 4) | (3u << 5));

    mmio_write32(UART0_BASE + UART_CR, 1u | (1u << 8));  /* 再開起來 */
}

static void uart_putc(char c)
{
    while (mmio_read32(UART0_BASE + UART_FR) & FR_TXFF) {
        ;
    }
    mmio_write32(UART0_BASE + UART_DR, (uint32_t)(unsigned char)c);
}

static void uart_puts(const char *s)
{
    while (*s != '\0') {
        uart_putc(*s++);
    }
}

void kernel_main(void)
{
    uart_init();
    uart_puts("step45\n");
    while (1) { }
}
