/*
 * 階梯 5：把 .bss 清成 0。
 *
 * 誰會跑我： make step5   -M virt
 *           make step6   -M virt,virtualization=on
 *
 * 沒有 step6.S 這個檔案。階梯 6 跑的就是這一份，只換 QEMU 機器參數，
 * 用來看「同一份程式在 EL2 開機時會發生什麼」。
 */

.section .text.boot, "ax"

.global _start
_start:
    ldr     x9, =__stack_top
    mov     sp, x9

    ldr     x9, =__bss_start
    ldr     x10, =__bss_end
bss_zero:
    cmp     x9, x10
    b.hs    enter_c                 /* unsigned: addresses have no sign */
    stp     xzr, xzr, [x9], #16     /* post-index: write, then advance */
    b       bss_zero

enter_c:
    bl      kernel_main

here:
    b       here
