/*
 * string.c - memset / memcpy / strlen / strcmp.
 *
 * Byte at a time, deliberately. With the MMU off the architecture treats all
 * memory as Device-nGnRnE (non-Gathering, non-Reordering, no Early write
 * acknowledgement), which permits no unaligned access at all. A word-at-a-time
 * copy would therefore have to align its ends by hand; the byte loop needs no
 * such care. QEMU does not enforce the rule by default, which is what would
 * make getting it wrong expensive to find.
 *
 * docs/guide/m2-uart.html
 */

#include "string.h"

void *memset(void *dst, int c, size_t n)
{
    /* c is an int by the standard, but only its low byte is stored. */
    unsigned char *p = dst;
    unsigned char v = (unsigned char)c;

    while (n-- > 0) {
        *p++ = v;
    }

    return dst;
}

/* restrict is the promise that the two regions do not overlap. Overlapping
 * copies are undefined behaviour here - that job belongs to memmove. */
void *memcpy(void *restrict dst, const void *restrict src, size_t n)
{
    unsigned char *d = dst;
    const unsigned char *s = src;

    while (n-- > 0) {
        *d++ = *s++;
    }

    return dst;
}

size_t strlen(const char *s)
{
    const char *p = s;

    while (*p != '\0') {
        p++;
    }

    return (size_t)(p - s);
}

/* Compares as unsigned char, which the standard requires. Plain char is
 * unsigned on AArch64 and signed on x86, so the cast is what keeps the sign
 * of the result the same on both. */
int strcmp(const char *a, const char *b)
{
    const unsigned char *pa = (const unsigned char *)a;
    const unsigned char *pb = (const unsigned char *)b;

    while (*pa != '\0' && *pa == *pb) {
        pa++;
        pb++;
    }

    return (int)*pa - (int)*pb;
}
