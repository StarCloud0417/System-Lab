/*
 * pl011.c - PL011 UART driver.
 *
 * QEMU emits characters with no setup at all, so uart_init() cannot be
 * verified here - only that the values reach the registers. It is written for
 * M9's real hardware; see docs/guide/m2-uart.html.
 */

#include <stdint.h>

#include "mmio.h"
#include "platform.h"
#include "uart.h"

/* Register offsets from the PL011 base. */
#define UART_DR         0x00    /* data */
#define UART_FR         0x18    /* flags */
#define UART_IBRD       0x24    /* baud divisor, integer part */
#define UART_FBRD       0x28    /* baud divisor, fraction in 1/64ths */
#define UART_LCR_H      0x2c    /* line control, high byte (UARTLCR_H) */
#define UART_CR         0x30    /* control */

#define FR_TXFF         (1u << 5)   /* transmit FIFO full */

#define LCR_H_FEN       (1u << 4)   /* enable the FIFOs: 16-entry hardware
                                       queues, so software need not keep pace
                                       with the wire character by character */
#define LCR_H_WLEN8     (3u << 5)   /* WLEN is a 2-bit field counting up from
                                       5 bits, so 8 bits encodes as 3 */

#define CR_UARTEN       (1u << 0)   /* UART enable */
#define CR_TXE          (1u << 8)   /* transmit enable */

void uart_init(void)
{
    /* Reprogramming a running UART corrupts whatever it is sending, silently.
     * Disable first, configure, then re-enable.
     *
     * The TRM also says to wait for FR.BUSY to clear and to flush the FIFO
     * before reprogramming. Neither is done here: QEMU hands us a UART that
     * was never enabled (CR = 0x300, UARTEN = 0), so there is nothing in
     * flight to wait for. M9's firmware prints before we start, so that is
     * where those two steps earn their place. */
    mmio_write32(UART0_BASE + UART_CR, 0);

    /* The divisor is clk / (16 * baud), split into whole parts and 1/64ths.
     * Keeping it entirely in 1/64ths needs one division, because 64/16 = 4:
     *
     *     64 * divisor = 64 * clk / (16 * baud) = 4 * clk / baud
     *
     * The +1)/2 is the integer form of the TRM's "+ 0.5" rounding. Plain
     * truncation happens to agree at 24 MHz but is one 1/64th low at the
     * Pi 4's 48 MHz. Deriving both registers from the same value also carries
     * correctly: a fraction that rounds up to 64 bumps IBRD instead of
     * overflowing FBRD's 6 bits. */
    uint32_t div64 = (uint32_t)((UART0_CLK_HZ * 8UL / UART0_BAUD + 1UL) / 2UL);
    mmio_write32(UART0_BASE + UART_IBRD, div64 / 64u);
    mmio_write32(UART0_BASE + UART_FBRD, div64 % 64u);

    /* Writing LCR_H is what latches IBRD/FBRD, so it must come after them. */
    mmio_write32(UART0_BASE + UART_LCR_H, LCR_H_FEN | LCR_H_WLEN8);

    /* No RX enable: nothing reads yet. The echo commit adds it and brings
     * its own reason. */
    mmio_write32(UART0_BASE + UART_CR, CR_UARTEN | CR_TXE);
}

/* Raw: no newline translation. Everything that reaches the wire goes here. */
static void uart_putc_raw(char c)
{
    /* The transmit FIFO is 16 deep on real hardware and writing to a full one
     * drops the character. QEMU drains instantly, so this spins zero times and
     * removing it changes nothing observable here. */
    while (mmio_read32(UART0_BASE + UART_FR) & FR_TXFF) {
        ;
    }
    mmio_write32(UART0_BASE + UART_DR, (uint32_t)(unsigned char)c);
}

void uart_putc(char c)
{
    /* A terminal moves down but not left on a bare '\n'. Translating here
     * rather than in uart_puts keeps this the single exit: printf will call
     * uart_putc one character at a time and must not have to remember. */
    if (c == '\n') {
        uart_putc_raw('\r');
    }
    uart_putc_raw(c);
}

void uart_puts(const char *s)
{
    while (*s != '\0') {
        uart_putc(*s++);
    }
}
