/*
 * 階梯 6：鮑率的兩種算法，在哪個時脈上會分岔。
 *
 * 誰會跑我： make step6
 *
 * 兩種都算，把四個值搬進暫存器讓 GDB 讀。
 * QEMU 的 24 MHz 兩者相同 —— 那正是第一版寫錯卻沒被抓到的原因。
 */

#include <stdint.h>

/* 無條件捨去（第一版） */
static uint32_t div64_floor(uint32_t clk, uint32_t baud)
{
    return clk * 4u / baud;
}

/* 四捨五入（TRM） */
static uint32_t div64_round(uint32_t clk, uint32_t baud)
{
    return (clk * 8u / baud + 1u) / 2u;
}

volatile uint32_t q_floor_ibrd, q_floor_fbrd, q_round_ibrd, q_round_fbrd;
volatile uint32_t p_floor_ibrd, p_floor_fbrd, p_round_ibrd, p_round_fbrd;

/* 斷點打在這裡：位址由 nm 查，不受程式長度影響。 */
void done(void);
void done(void) { }

void kernel_main(void)
{
    uint32_t d;

    d = div64_floor(24000000u, 115200u);  q_floor_ibrd = d / 64u; q_floor_fbrd = d % 64u;
    d = div64_round(24000000u, 115200u);  q_round_ibrd = d / 64u; q_round_fbrd = d % 64u;
    d = div64_floor(48000000u, 115200u);  p_floor_ibrd = d / 64u; p_floor_fbrd = d % 64u;
    d = div64_round(48000000u, 115200u);  p_round_ibrd = d / 64u; p_round_fbrd = d % 64u;

    done();
    while (1) { }
}
