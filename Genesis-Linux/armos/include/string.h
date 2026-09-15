/*
 * string.h - The handful of libc functions a freestanding kernel still needs.
 *
 * Signatures match ISO C exactly. Under -ffreestanding GCC's built-in knowledge
 * of these names is switched off, so what catches a wrong signature is this
 * header disagreeing with lib/string.c - measured, not assumed.
 *
 * docs/guide/m2-uart.html
 */

#ifndef STRING_H
#define STRING_H

#include <stddef.h>

void *memset(void *dst, int c, size_t n);
void *memcpy(void *restrict dst, const void *restrict src, size_t n);
size_t strlen(const char *s);
int strcmp(const char *a, const char *b);

#endif /* STRING_H */
