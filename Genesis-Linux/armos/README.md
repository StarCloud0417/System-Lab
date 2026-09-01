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
| M0 | 環境建置與最小可開機映像 | 進行中 |
| M1 | 開機流程：核心篩選、EL 降級、堆疊與 BSS | |
| M2 | PL011 UART 驅動與 printf | |
| M3 | 例外向量表與同步例外處理 | |
| M4 | GICv2 中斷控制器與 Generic Timer | |
| M5 | MMU 與 Cache | |
| M6 | 實體記憶體管理（bitmap → 夥伴系統） | |
| M7 | 行程與 Context Switch | |
| M8 | User Mode 與 System Call | |
| M9 | 移植到 Raspberry Pi 4 | |
| M10 | SMP 基礎機制（選配） | |
| M11 | fork、exec 與 Copy-on-Write（選配） | |

## 環境需求

在 Ubuntu / Debian 上：

```bash
sudo apt install gcc-aarch64-linux-gnu qemu-system-arm \
                 gdb-multiarch device-tree-compiler make
```

四樣東西各自的用途：交叉編譯器（在 x86-64 上產生 ARM64 的碼）、模擬器、除錯器
（一般的 `gdb` 認不得 aarch64 目標）、以及讀 device tree 用的工具。

本專案目前在這組版本上開發與量測：

```
binutils 2.38 / gcc 11.4.0 / QEMU 6.2.0 / gdb 12.1  (Ubuntu 22.04)
```

版本不必完全一樣，但差太多的話文件裡的數值可能對不上 —— `ld` 的孤兒 section 擺放
規則、`gdb` 的 prologue 判斷、預設頁大小三者都會隨版本改變。

## 怎麼用

```bash
make            # 建置（零警告，本專案使用 -Werror）
make dump       # 反組譯 + ELF header + program header
make qemu       # 在 QEMU 上執行（離開：先按 Ctrl-A，放開，再按 X）
make debug      # QEMU 停在第一條指令並接上 GDB
make dtb        # 印出 QEMU virt 的 device tree，查平台位址
make clean
```

### 最短路徑：三分鐘看到 CPU 在跑

```bash
$ make
$ make dump          # Entry point address 應該是 0x40000000
$ make debug
```

`make debug` 會自動比對兩次 `x0`：

```
Breakpoint 1, 0x0000000040000008 in halt_loop ()
$1 = 1

Breakpoint 1, 0x0000000040000008 in halt_loop ()
$2 = 2
(gdb)
```

**兩個值不同就過關了。**這同時證明了兩件事：映像確實被載進記憶體（不然斷點不會
命中），而且 CPU 確實在執行我們寫的指令（不然 `x0` 不會變）。

之所以要用一個遞增的計數器而不是一般的 `b .` 無窮迴圈，是因為停住的核心和空轉的
核心從外面看完全一樣 —— `b .` 沒辦法分辨「映像正確執行」與「映像根本沒載進去」。

`make qemu` 這時候畫面會是全黑的，那是正確的：UART 驅動要到 M2 才有。

## 怎麼做實驗

確認「一切正常」只是起點。裸機開發沒有 segfault 幫你擋，唯一的技能是**從症狀反推
原因**，所以更值得花時間的是故意把它弄壞。

下面四個實驗每個大約一分鐘，都可以用 `git checkout .` 復原。

| # | 改什麼 | 然後看 | 你會看到 |
|---|---|---|---|
| 1 | `linker/kernel-qemu.ld` 的 `0x40000000` → `0x41000000` | `make && make dump` | `_start` 跟著搬家。**不需要 `make clean`**，因為 Makefile 把 linker script 列進了相依項 |
| 2 | `kernel/boot.S` 的 `.text.boot` 拼錯成 `.txet.boot` | `make clean && make` | **零警告、零錯誤，而且照樣開得起來** |
| 3 | 拿掉 Makefile 的 `-Wl,--build-id=none` | `make clean && make dump` | entry point 變成 `0x40000024` |
| 4 | Makefile 的 `WARN` 加上 `-g` | `make clean && make debug` | 斷點從 `0x40000008` 跑回 `0x40000004`，第一次停時 `$1 = 0` |

實驗 2 是這個里程碑最重要的一課：**建置成功不等於做對了**。linker script 對
section 名稱是純字串比對，打錯不會有任何錯誤訊息。

每個實驗的原理與完整實測數據，見 `docs/guide/m0-build-and-boot.html` 第 7 節
「被推翻的直覺」。

## 目錄結構

```
kernel/         核心程式碼
linker/         各平台的 linker script
docs/guide/     圖解教材，一個里程碑一份
build/          建置產物（不進版控，可由原始碼完全重建）
```

## 文件的分工

四種文件各司其職，不互相重複：

| 位置 | 回答什麼 |
|---|---|
| `git log` | **結果**：這個 commit 做了什麼、為什麼這樣選 |
| `docs/guide/` | **原理**：為什麼會這樣運作，附實測數據與圖解 |
| `docs/journal/` | **過程**：當時卡在哪裡、怎麼查出來的 |
| `docs/adr/` | **決策**：為什麼選 A 不選 B，B 的代價是什麼 |

程式碼註解只留「為什麼這樣寫」的一兩句，完整說明在 `docs/guide/`，三個原始檔的
檔頭都標了對應的章節。

## 目前的核心

```asm
_start:
    mov     x0, xzr
halt_loop:
    add     x0, x0, #1
    b       halt_loop
```

三條指令，12 bytes。載到 `0x4000_0000` —— 這個位址不是慣例，是 QEMU virt 這塊板子
自己的 device tree 說的，跑 `make dtb` 就看得到出處。
