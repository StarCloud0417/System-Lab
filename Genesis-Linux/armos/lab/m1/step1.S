/*
 * 階梯 1：最小的核心。CPU 真的有跑到我的程式嗎？
 *
 * 誰會跑我： make step1
 */

.section .text.boot, "ax"

.global _start
_start:
    mov     x9, #0xaa               /* 一個看得出來的值 */
here:
    b       here                    /* 原地打轉：下面沒東西了 */
