# lab/m2 —— 用實驗驗證 M2 教材

`lab/m1` 是「從三行組語疊出 `boot.S`」；這一組不一樣：
**每一階都在驗證 `docs/guide/m2-uart.html` 裡的一條宣稱。**

前八階都在問同一個問題的不同版本 —— **「這樣東西是必要的嗎？」**
第九階是答案。

```bash
cd lab/m2
make            # 看有哪些階梯
make step1      # 從頭開始
```

---

## 九階在驗什麼

| 階梯 | 問題 | 答案 |
|---|---|---|
| 1 | 不初始化，直接往 `DR` 寫，會有輸出嗎？ | 有。`4142 0a` = `AB\n` |
| 2 | 那開機時那些設定暫存器長什麼樣？ | `UARTEN = 0`、`IBRD = 0`、`LCR_H = 0` |
| 3 | 用 C 寫，沒 init、沒 `volatile`、沒等待迴圈呢？ | 照樣能動 |
| 4 | `volatile` 在 `-O0` 下有差別嗎？ | **沒有**，產出一模一樣 |
| 5 | `-O2` 呢？ | **少一條 `str`** ★ |
| 6 | 鮑率的捨去和四捨五入差在哪？ | 24 MHz 相同，48 MHz 差一格 |
| 7 | CR/LF 轉換放 `uart_puts` 裡會怎樣？ | `putc('\n')` 送出裸 `0a` |
| 8 | `TXFF` 等待迴圈跑幾圈？ | **0 圈** |
| 9 | 所以正式版為什麼長那樣？ | 與 `drivers/uart/pl011.c` 相同 |

## 階梯 5：這一階是重點

拿掉 `volatile`、用 `-O2` 編，`uart_init()` 裡的 `str` 從 **5 條變 4 條**。

少的那一條是 **`CR = 0`**（「先關掉」）。編譯器看到 `CR` 被寫兩次，把第一次當成
**死存取**刪掉了 —— 而那正是註解裡說要保護飛行中字元的那一行。

**而且它在 QEMU 上照樣印得出來，完全隱形。**

兩個教訓：

- `volatile` 不是為了現在，是為了 `-O2`（`PROJECT_PLAN` 有規定，Makefile 還沒設）
- **「拿掉它現在會壞嗎」這個判準，要連編譯旗標一起問**

## 做這個 lab 的時候踩到的坑

`#include "mmio.h"` **會先找原始檔自己的目錄**，`-I` 排在後面。

所以「拿掉 `volatile` 的對照組」不能只加 `-I` 指向改過的標頭 —— 原始檔也必須
複製到那個目錄，否則它會繼續用隔壁那份有 `volatile` 的。

第一版就是這樣寫的，結果「有 / 無 volatile」兩組都是 5 條，看起來像
「編譯器沒刪」。**實驗安靜地測到了錯的東西**，而且症狀看起來像一個真實的結論。

`run.sh` 的 `novol()` 現在會把原始檔一起複製過去，註解也寫了理由。

## 想自己在 GDB 裡面翻

```bash
cd lab/m2
./run.sh step9              # 先跑一次，順便編譯出 build/step9.elf
pkill -x qemu-system-aar    # 清場

qemu-system-aarch64 -M virt -cpu cortex-a72 -display none -serial none \
    -kernel build/step9.elf -S -s &
gdb-multiarch -q build/step9.elf -ex 'target remote :1234'
```

沒有 `-g`，所以 GDB 不知道全域變數的型別，要自己 cast。位址用 `nm` 查：

```bash
aarch64-linux-gnu-nm build/step8.elf | grep -E 'spins|fr_or|done'
```

```
p/x *(unsigned int *)0x40000...     讀一個 32 位元的值
p/x *(unsigned int *)0x09000030     PL011 的 CR
p/x *(unsigned int *)0x09000018     PL011 的 FR
x/2i $pc                            往下看兩條指令
```

> ⚠️ 清 QEMU 一律用 `pkill -x qemu-system-aar`。
> Linux 的行程名上限 15 字元，`qemu-system-aarch64` 有 19 個，用全名比對不到。
> 而 `pkill -f` 比對完整命令列，會**連跑這條指令的 shell 一起殺掉**。

## 幾個檔案的關係

- `step9.c` 與 `drivers/uart/pl011.c` 相同，只多一個 `kernel_main()` 讓它印一句話
- `boot.S`、`kernel-qemu.ld`、`mmio.h`、`platform.h` 是 **M2 當時的快照**，
  不跟著後面的里程碑走
- 原理（為什麼這樣寫、哪些直覺被推翻）在
  [`docs/guide/m2-uart.html`](../../docs/guide/m2-uart.html)

> `git log` 記結論，`docs/guide/` 講原理，`lab/` 讓你重新跑一遍。
