/*
 * printf.c - %c %s %d %u %x %p %%, with a minimum field width and zero fill.
 *
 * No length modifiers yet: nothing prints a 64-bit value except %p, which is
 * always a pointer. M3 prints system registers and can add 'l' then, with a
 * reason of its own.
 *
 * Output goes straight to uart_putc, one character at a time. There is no
 * buffering on purpose - the last line before a crash has to already be out.
 *
 * docs/guide/m2-uart.html
 */

#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

#include "printf.h"
#include "string.h"
#include "uart.h"

/* Worst case is 20 characters: UINT64_MAX is 20 digits and unsigned, while
 * INT64_MIN's magnitude is 19 digits plus a sign. %p is 16 hex digits, and its
 * "0x" is emitted directly rather than through this buffer. */
#define NUM_BUF_MAX     24

/* Carried through instead of a file-scope counter: M4 adds interrupts, and a
 * shared counter would make printf unsafe to call from a handler. */
struct out {
    int count;
};

static void emit(struct out *o, char c)
{
    uart_putc(c);
    o->count++;
}

static void pad(struct out *o, char c, int n)
{
    while (n-- > 0) {
        emit(o, c);
    }
}

static void put_str(struct out *o, const char *s, int width)
{
    if (s == NULL) {
        s = "(null)";
    }

    int len = (int)strlen(s);

    pad(o, ' ', width - len);
    for (int i = 0; i < len; i++) {
        emit(o, s[i]);
    }
}

/* Digits come out least significant first, so they are built backwards into
 * buf and then walked forwards. */
static void put_num(struct out *o, uint64_t v, unsigned base, int negative,
                    int width, char fill)
{
    char buf[NUM_BUF_MAX];
    int n = 0;

    do {
        buf[n++] = "0123456789abcdef"[v % base];
        v /= base;
    } while (v != 0);

    if (negative) {
        /* A zero fill goes after the sign, a space fill before it. */
        if (fill == '0') {
            emit(o, '-');
            width--;
        } else {
            buf[n++] = '-';
        }
    }

    pad(o, fill, width - n);
    while (n-- > 0) {
        emit(o, buf[n]);
    }
}

int printf(const char *fmt, ...)
{
    struct out o = { .count = 0 };
    va_list ap;

    va_start(ap, fmt);

    for (const char *p = fmt; *p != '\0'; p++) {
        if (*p != '%') {
            emit(&o, *p);
            continue;
        }

        p++;

        char fill = ' ';
        if (*p == '0') {
            fill = '0';
            p++;
        }

        int width = 0;
        while (*p >= '0' && *p <= '9') {
            width = width * 10 + (*p - '0');
            p++;
        }

        switch (*p) {
        case 'c':
            /* Default argument promotion turns char into int, so int is the
             * only type va_arg may be given here. */
            pad(&o, ' ', width - 1);
            emit(&o, (char)va_arg(ap, int));
            break;
        case 's':
            put_str(&o, va_arg(ap, const char *), width);
            break;
        case 'd': {
            int v = va_arg(ap, int);
            /* Negated as unsigned: -INT_MIN overflows as a signed int. */
            uint64_t mag = (v < 0) ? -(uint64_t)v : (uint64_t)v;
            put_num(&o, mag, 10, v < 0, width, fill);
            break;
        }
        case 'u':
            put_num(&o, va_arg(ap, unsigned int), 10, 0, width, fill);
            break;
        case 'x':
            put_num(&o, va_arg(ap, unsigned int), 16, 0, width, fill);
            break;
        case 'p':
            emit(&o, '0');
            emit(&o, 'x');
            put_num(&o, (uint64_t)(uintptr_t)va_arg(ap, void *), 16, 0, 16, '0');
            break;
        case '%':
            emit(&o, '%');
            break;
        case '\0':
            /* A trailing '%' - step back so the loop's p++ does not run past
             * the terminator. */
            p--;
            break;
        default:
            emit(&o, '%');
            emit(&o, *p);
            break;
        }
    }

    va_end(ap);
    return o.count;
}
