# armos

從 `boot.S` 開始自幹的 AArch64 作業系統核心。

開發平台是 QEMU 的 `virt` 機器，移植目標是 Raspberry Pi 4（BCM2711）。不用任何
現成的 bootloader、不連 libc，`memcpy` 之類的東西都自己寫。

這是一個**學習專案**，目的是弄懂每一行為什麼要這樣寫。所以除了程式碼之外，每個
里程碑都會留下一份圖解教材（`docs/guide/`），把當下量到的數據、踩過的坑、以及
被實測推翻的直覺一起寫進去。

## 進度

| 里程碑 | 內容 | 狀態 |
|---|---|---|
| M0 | 環境建置與最小可開機映像 | **完成** |
| M1 | 開機流程：EL 降級、堆疊與 BSS | **完成** |
| M2 | PL011 UART 驅動與 printf | 進行中 |
| M3 | 例外向量表與同步例外處理 | |
| M4 | GICv2 中斷控制器與 Generic Timer | |
| M5 | MMU 與 Cache | |
| M6 | 實體記憶體管理（bitmap → 夥伴系統） | |
| M7 | 行程與 Context Switch | |
| M8 | User Mode 與 System Call | |
| M9 | 移植到 Raspberry Pi 4（含 `MPIDR_EL1` 核心篩選）| |
| M10 | SMP 基礎機制（選配） | |
| M11 | fork、exec 與 Copy-on-Write（選配） | |

> M1 原訂含「依 `MPIDR_EL1` 篩選 core 0」，實測 QEMU 的 `-M virt` 不放出副核心
> （CPU#1–#3 停在 `_start`，一條指令都沒執行），那段程式碼在這裡驗不了，整包移到 M9。
> 理由與實測見 [`docs/guide/00-arm-map.html`](docs/guide/00-arm-map.html) 第 3 節。

## 環境需求

在 Ubuntu / Debian 上：

```bash
sudo apt install gcc-aarch64-linux-gnu qemu-system-arm \
                 gdb-multiarch device-tree-compiler make
```

四樣東西各自的用途：交叉編譯器（在 x86-64 上產生 ARM64 的碼）、模擬器、除錯器
（一般的 `gdb` 認不得 aarch64 目標）、以及讀 device tree 用的工具。

裝好之後跑一次：

```bash
make check-env
```

```
檢查工具鏈（CROSS=aarch64-linux-gnu-）

  [就緒] aarch64-linux-gnu-gcc      11.4.0
  [就緒] aarch64-linux-gnu-ld       2.38
  [就緒] aarch64-linux-gnu-objdump  2.38
  [就緒] aarch64-linux-gnu-readelf  2.38
  [就緒] qemu-system-aarch64        6.2.0
  [就緒] gdb-multiarch              12.1
  [就緒] dtc                        1.6.1
  [就緒] ss                         5.15.0

工具齊備，版本與文件一致。
```

缺工具會列出全部缺的並回傳失敗；版本與文件不同只會提醒，核心照樣建得起來。

之所以要比對版本，是因為文件裡有大量實測數值（ELF 大小、斷點位址、section 對齊），
而這些數字會隨工具版本改變 —— `ld` 的孤兒 section 擺放規則、`gdb` 的 prologue 判斷、
預設頁大小三者都是。**版本不同時不會有任何錯誤訊息**，照著文件做的人只會發現數字
對不上，卻不知道為什麼。本專案的量測環境是：

```
binutils 2.38 / gcc 11.4.0 / QEMU 6.2.0 / gdb 12.1  (Ubuntu 22.04)
```

若工具鏈的前綴不是 `aarch64-linux-gnu-`（有些發行版是 `aarch64-none-elf-`），
改 Makefile 開頭的 `CROSS` 即可，`check-env` 會跟著走。

## 怎麼用

```bash
make check-env  # 檢查工具鏈是否齊備
make            # 建置（零警告，本專案使用 -Werror）
make dump       # 反組譯 + ELF header + program header
make qemu       # 在 QEMU 上執行（離開：先按 Ctrl-A，放開，再按 X）
make debug      # QEMU 停在第一條指令並接上 GDB
make qemu-el2   # 同上，但在 EL2 交接（模擬樹莓派韌體）
make debug-el2  # 同 debug，但在 EL2 交接
make dtb        # 印出 QEMU virt 的 device tree，查平台位址
make clean
```

### 最短路徑：三分鐘看到 CPU 在跑

```bash
$ make
$ make dump          # Entry point address 應該是 0x40000000
$ make debug
```

`make debug` 會自動比對兩次 `x10`：

```
Breakpoint 1, 0x0000000040000030 in halt_loop ()
$1 = 1

Breakpoint 1, 0x0000000040000030 in halt_loop ()
$2 = 2
(gdb)
```

**兩個值不同就過關了。**這同時證明了兩件事：映像確實被載進記憶體（不然斷點不會
命中），而且 CPU 確實在執行我們寫的指令（不然 `x10` 不會變）。

計數器用 `x10` 而不是 `x0`，是因為 AArch64 的開機協定規定 `x0` 帶著 device tree
的位址，樹莓派的韌體就是這樣傳的 —— 那幾顆暫存器要原封不動留給後面的里程碑。

`make debug-el2` 會印出**一模一樣**的結果，但它是從 EL2 進入、自己降到 EL1 的。
兩者相同，正是降級有效的證明。

之所以要用一個遞增的計數器而不是一般的 `b .` 無窮迴圈，是因為停住的核心和空轉的
核心從外面看完全一樣 —— `b .` 沒辦法分辨「映像正確執行」與「映像根本沒載進去」。

`make qemu` 會印出 `Hello, AArch64 from EL1`。離開：先按 Ctrl-A，放開，再按 X。

## 怎麼做實驗

確認「一切正常」只是起點。裸機開發沒有 segfault 幫你擋，唯一的技能是**從症狀反推
原因**，所以更值得花時間的是故意把它弄壞。

### 最快的入口：`lab/m1`

不用改任何檔案，也不用手動記位址：

```bash
cd lab/m1
make            # 看有哪些階梯
make step1      # 從三行組語開始，一路疊到完整的 boot.S
```

九個階梯，**每一階都是被上一階的失敗逼出來的**：沒堆疊就炸給你看，炸完才加堆疊；
在 EL2 開機一切正常但樓層是錯的，才需要降級。每個 `make stepN` 會自動編譯、
開 QEMU、接 GDB、停在該看的地方。位址用 `nm` 查，程式變長也不用改東西。

`lab/m1/step9.S` 跟 `kernel/boot.S` 的指令完全相同 —— 爬完九階，手上就是這份核心。
細節見 [`lab/m1/README.md`](lab/m1/README.md)。

### 直接改 repo 的檔案

下面幾個實驗每個大約一分鐘，都可以用 `git checkout .` 復原。

| # | 改什麼 | 然後看 | 你會看到 |
|---|---|---|---|
| 1 | `linker/kernel-qemu.ld` 的 `0x40000000` → `0x41000000` | `make && make dump` | `_start` 跟著搬家。**不需要 `make clean`**，因為 Makefile 把 linker script 列進了相依項 |
| 2 | `kernel/boot.S` 的 `.text.boot` 拼錯成 `.txet.boot` | `make clean && make` | **零警告、零錯誤，而且照樣開得起來** |
| 3 | 拿掉 Makefile 的 `-Wl,--build-id=none` | `make clean && make dump` | entry point 從 `0x40000000` 變成 `0x40000028` —— 連結器把一個 `.note.gnu.build-id` 塞到最前面，把 `_start` 推走了 |
| 4 | Makefile 的 `WARN` 加上 `-g` | `make clean && make debug` | 斷點位址**不變**（都是 `0x4000009c`），但訊息多了 `file kernel/start.c, line 23`，而且 `print boot_counter` 不用再自己 cast 型別 |
| 5 | 把 `boot.S` 從 `mov x9, #(1 << 31)` 到 `eret` 整段刪掉 | `make clean && make debug-el2` | 核心照樣跑，但 `p ($cpsr >> 2) & 3` 是 **2** —— 卡在 EL2 沒降下來 |

實驗 2 是這個里程碑最重要的一課：**建置成功不等於做對了**。linker script 對
section 名稱是純字串比對，打錯不會有任何錯誤訊息。

實驗 4 值得注意的是**它沒有改變什麼**。`-g` 只是多塞六個 `.debug_*` 區段
（檔案 67200 → 68688 bytes），一條指令都沒動，所以 GDB 跳過函式序言的位置也不會變。
它讓 GDB 看得懂型別 —— 這就是為什麼沒有 `-g` 時，`make debug` 得寫成
`print *(unsigned long *)&boot_counter` 而不能只寫 `print boot_counter`。

每個實驗的原理與完整實測數據，見 `docs/guide/m0-build-and-boot.html` 第 7 節
「被推翻的直覺」。

## 目錄結構

```
kernel/         核心程式碼
drivers/        週邊驅動，一個裝置一個目錄
include/        標頭檔。platform.h 收所有平台相依的位址
linker/         各平台的 linker script
docs/guide/     圖解教材，一個里程碑一份
lab/            可執行的實驗場，一個里程碑一組
build/          建置產物（不進版控，可由原始碼完全重建）
```

## 文件的分工

| 位置 | 回答什麼 |
|---|---|
| `git log` | **結果**：這個 commit 做了什麼、為什麼這樣選 |
| `docs/guide/00-arm-map.html` | **全局**：一顆 ARM64 從通電到跑起 OS 的整張地圖，標出每一格「我們走到哪了」。**建議先讀這份** |
| `docs/guide/` | **原理**：為什麼會這樣運作，附實測數據與圖解。目前有 [M0](docs/guide/m0-build-and-boot.html)、[M1](docs/guide/m1-boot-flow.html) |
| `lab/` | **怎麼跑**：可執行的階梯，一個 `make` 指令跑一階。目前有 [M1](lab/m1/README.md) |

兩者不重複：commit message 記「這次改了什麼、為什麼」，教材記「它為什麼會這樣運作」。
設計上的取捨直接寫在對應的教材裡，跟原理放在一起。

程式碼註解只留「為什麼這樣寫」的一兩句，完整說明在 `docs/guide/`，每個原始檔的
檔頭都標了對應的章節。

## 目前的核心

開機之後印出一行字。`boot.S` 把機器整理成固定狀態，交給 C：

```c
void kernel_main(void)
{
    uart_init();
    uart_puts("Hello, AArch64 from EL1\n");
    ...
}
```

在那之前，`boot.S` 做完三件事——統一特權等級、給堆疊、清 `.bss`：

```asm
_start:
    mrs     x9, CurrentEL           /* 我在哪一層？ */
    cmp     x9, #(1 << 2)
    b.eq    el1_entry               /* 已經在 EL1 就跳過 */

    mov     x9, #(1 << 31)          /* HCR_EL2.RW: EL1 用 AArch64 */
    msr     hcr_el2, x9
    mov     x9, #0x3c5              /* SPSR_EL2: EL1h, DAIF 全遮 */
    msr     spsr_el2, x9
    adr     x9, el1_entry
    msr     elr_el2, x9
    eret                            /* 往下走的唯一辦法 */

el1_entry:
    mov     x10, xzr
halt_loop:
    add     x10, x10, #1
    b       halt_loop
```

13 條指令，52 bytes。載到 `0x4000_0000` —— 這個位址不是慣例，是 QEMU virt 這塊板子
自己的 device tree 說的，跑 `make dtb` 就看得到出處。

前面那段是在處理「韌體把我們丟在哪一層」的差異：QEMU 一般開機直接就是 EL1，
樹莓派和 `virtualization=on` 則是 EL2。原理見
[`docs/guide/m1-boot-flow.html`](docs/guide/m1-boot-flow.html)。
