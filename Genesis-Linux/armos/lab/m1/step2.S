/*
 * 階梯 2：我在哪一層？只把 step1 的 mov 換成 mrs。
 *
 * 誰會跑我： make step2
 */

.section .text.boot, "ax"

.global _start
_start:
    mrs     x9, CurrentEL           /* reads as EL * 4 */
here:
    b       here
