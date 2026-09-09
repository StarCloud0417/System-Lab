/*
 * 階梯 7：CR/LF 轉換放在 uart_puts 裡的後果。
 *
 * 誰會跑我： make step7
 *
 * 這是第一版的寫法。看輸出的位元組：uart_puts("a\n") 補了 \r，
 * uart_putc('\n') 沒有 —— 而 printf 是逐字元呼叫 putc 的。
 */

#include <stdint.h>

#include "mmio.h"
#include "platform.h"

#define UART_DR 0x00

static void putc_v1(char c)
{
    mmio_write32(UART0_BASE + UART_DR, (uint32_t)(unsigned char)c);
}

static void puts_v1(const char *s)
{
    while (*s != '\0') {
        if (*s == '\n') {
            putc_v1('\r');      /* 轉換只發生在這裡 */
        }
        putc_v1(*s++);
    }
}

void kernel_main(void)
{
    puts_v1("A\n");             /* 期望 41 0d 0a */
    putc_v1('B');
    putc_v1('\n');              /* 期望 42 0a —— 少了 0d */
    while (1) { }
}
