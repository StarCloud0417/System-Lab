/*
 * 階梯 1：完全不初始化，直接往 PL011 的資料暫存器寫字元。
 *
 * 誰會跑我： make step1
 *
 * 教材第 7 節「直覺 1」說 QEMU 上不用初始化。這一階就是那句話的證據。
 */

.section .text.boot, "ax"

.global _start
_start:
    ldr     x0, =0x09000000         /* PL011 的 DR，位址來自 make dtb */
    mov     w1, #'A'
    str     w1, [x0]
    mov     w1, #'B'
    str     w1, [x0]
    mov     w1, #'\n'
    str     w1, [x0]
here:
    b       here
