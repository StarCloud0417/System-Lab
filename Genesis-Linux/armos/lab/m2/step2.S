/*
 * 階梯 2：階梯 1 成功了 —— 那開機時那些設定暫存器到底長什麼樣？
 *
 * 誰會跑我： make step2
 *
 * 把六個暫存器搬進通用暫存器，讓 GDB 讀得到（GDB 讀不到 MMIO 以外的裝置狀態，
 * 但這裡是 MMIO，直接讀位址也行 —— 用 mrs 風格是為了跟 M1 的手法一致）。
 */

.section .text.boot, "ax"

.global _start
_start:
    ldr     x0, =0x09000000
    ldr     w21, [x0, #0x30]        /* CR    控制暫存器 */
    ldr     w22, [x0, #0x24]        /* IBRD  鮑率整數部 */
    ldr     w23, [x0, #0x28]        /* FBRD  鮑率小數部 */
    ldr     w24, [x0, #0x2c]        /* LCR_H 行控制 */
    ldr     w25, [x0, #0x18]        /* FR    旗標 */
    ubfx    w26, w21, #0, #1        /* CR 的 bit0 = UARTEN */
here:
    b       here
