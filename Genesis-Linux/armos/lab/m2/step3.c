/*
 * 階梯 3：用 C 寫最小的 putc。沒有初始化、沒有 volatile、沒有 TXFF 等待。
 *
 * 誰會跑我： make step3   （也是階梯 4、5 拿來比對的那份原始碼）
 *
 * 就這樣還是會動 —— 所以「初始化」「volatile」「等待迴圈」三樣，
 * 在 QEMU 上到底哪一樣是必要的？後面三階一個一個問。
 */

#include <stdint.h>

#define UART_DR     0x09000000UL

static void putc_naive(char c)
{
    *(uint32_t *)UART_DR = (uint32_t)(unsigned char)c;
}

void kernel_main(void)
{
    const char *s = "step3: no init, no volatile\n";
    while (*s != '\0') {
        putc_naive(*s++);
    }
    while (1) { }
}
