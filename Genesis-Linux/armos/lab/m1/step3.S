/*
 * 階梯 3：直接呼叫 C。沒有堆疊，會炸。
 *
 * 誰會跑我： make step3
 */

.section .text.boot, "ax"

.global _start
_start:
    bl      kernel_main

here:
    b       here
