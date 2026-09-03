/*
 * 階梯 4：先給堆疊，再呼叫 C。C 活了，但 .bss 還沒清。
 *
 * 誰會跑我： make step4
 */

.section .text.boot, "ax"

.global _start
_start:
    ldr     x9, =__stack_top
    mov     sp, x9

    bl      kernel_main

here:
    b       here
