/*
 * printf.h - Formatted output over the UART.
 *
 * The format attribute is not decoration: it makes GCC type-check every call
 * site against the format string, and -Werror turns a mismatch into a build
 * failure. Nothing else in a freestanding kernel checks these.
 *
 * docs/guide/m2-uart.html
 */

#ifndef PRINTF_H
#define PRINTF_H

/*
 * Supported: %c %s %d %u %x %p %%, optionally preceded by '0' and a minimum
 * field width, as in %08x.
 *
 * Anything else ISO C allows - flags (- + # space), a precision (.n) or a
 * length modifier (l, hh) - is NOT implemented. Such a directive is printed
 * verbatim and its argument is never consumed, so every argument after it is
 * read from the wrong place. The format attribute below does not catch this:
 * it checks types against ISO C, and those directives are valid ISO C.
 *
 * So printf("%016lx", esr) prints the four characters %lx, not the value.
 */
int printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

#endif /* PRINTF_H */
