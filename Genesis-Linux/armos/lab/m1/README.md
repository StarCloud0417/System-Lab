# lab/m1 —— 從零疊出 `boot.S`

九個階梯，從三行組語疊到 `kernel/boot.S` 的完整版。

**每一階都是被上一階的失敗逼出來的。** 不是「先看正確答案再拆解」，
是「先撞牆，再問怎麼修」。

```bash
cd lab/m1
make            # 看有哪些階梯
make step1      # 從頭開始
```

每個 `make stepN` 會自動：編譯 → 開 QEMU → 接 GDB → 停在該看的地方 → 收工。
**位址一律用 `nm` 查，不寫死**，所以每一階程式長度不同也不用改任何東西。

---

## 九階在幹嘛

| 階梯 | 為什麼需要它 | 加了什麼 | 你會看到 |
|---|---|---|---|
| 1 | — | 三行：`mov` + 原地打轉 | `PC` 從 `0x40000000` 走到 `0x40000004`，然後不動 |
| 2 | 韌體把我丟在哪一層？ | 把 `mov` 換成 `mrs x9, CurrentEL` | `0x4` = EL1 |
| 3 | 核心後面要用 C 寫，先試最直接的：直接呼叫 | 直接 `bl kernel_main` | `SP = 0` → `stp` 炸 → `PC = 0x200`，**沒有任何錯誤訊息** |
| 4 | 階梯 3 死在「沒有堆疊」 | `ldr x9, =__stack_top` + `mov sp, x9` | C 活了。但 `boot_counter` 的髒值**原封不動** |
| 5 | 階梯 4 的髒值沒人清，而 C 保證未初始化全域變數是 0 | 清 `.bss` 的迴圈 | 開機前塞的 `0xcafe1234` 變成 `0x0` |
| 6 | 真機（樹莓派 4、開了虛擬化的 QEMU）不會把你丟在 EL1 | *（不改程式）* 改用 EL2 開機 | 不會炸，但 `EL = 2` —— **樓層錯了**（為什麼是錯的，見下面） |
| 7 | 階梯 6 停在 EL2，得自己走下來 | `HCR_EL2` / `SPSR_EL2` / `ELR_EL2` + `eret` | `eret` 前 `EL = 2`，`eret` 後 `EL = 1` |
| 8 | 階梯 7 只在 EL2 開機時對 | *（不改程式）* 改用一般開機 | 又炸到 `0x200`，但這次 `EL = 1` —— **成因完全不同** |
| 9 | 階梯 8 死在「沒先問自己在哪一層」 | 開頭先問 `CurrentEL` | 兩種開機方式，三個數字一字不差 |

**沒有 `step6.S` 和 `step8.S` 這兩個檔案。** 那兩階跑的是 `step5.S` 和 `step7.S`，
只換 QEMU 的機器參數。每一階的抬頭都會印它實際用了哪個 `.S`。

`make step9-el2` 是同一個 `step9.S` 換 EL2 開機。**跟 `make step9` 比對，
輸出應該完全一樣** —— 那就是 M1 的驗收標準。

## 階梯 6：EL2 權限更高，為什麼還算「錯」

跑完 step6 你會看到它一切正常，只有 `EL = 2`。權限比 EL1 高，直覺上應該更好才對。

**問題是每一層都有自己一整套暫存器**，名字像但物理上不是同一顆。`make vbar` 就在
證明這件事：在 EL2 執行 `msr vbar_el1, x9`，然後把兩顆都讀出來 ——

    EL       = 2
    VBAR_EL1 = 0x1000      ← 我寫的
    VBAR_EL2 = 0x0         ← 完全沒動

在 EL2 出事時，CPU 去查的是 `VBAR_EL2`。你照著任何教科書或 Linux 原始碼寫
`msr vbar_el1`，**例外處理器永遠不會被呼叫到，而且沒有錯誤訊息**。

後面的里程碑全都踩在這件事上：M3 的向量表、M5 的 `TTBR0_EL1`、M8 的
「EL0 出事時硬體預設送到 EL1」。**整個生態系都假設核心在 EL1。**

所以 `make vbar` 建議在 step6 卡住的時候就跑，不用等到最後。

## `0x200` 你會看到三次

三種完全不同的錯，長成同一個樣子：

| 指令 | 為什麼 | EL | `ESR_EL1` 的 EC |
|---|---|---|---|
| `make step3` | 堆疊沒設，`stp` 寫到 `0xffff_ffff_ffff_fff0` | 1 | `0x25` Data Abort |
| `make step8` | 在 EL1 碰 EL2 的暫存器 | 1 | `0x00` Unknown |
| `make norw` | `HCR_EL2.RW` 和 `SPSR_EL2.M[4]` 打架 | **2** | —（要看 `ESR_EL2`）|

`make norw` 是三者裡最特別的：**`eret` 真的執行了，但硬體拒絕換層**，改把
`PSTATE.IL`（Illegal Execution state，bit 20）設起來，等**下一次取指令**才 trap。
所以你會看到 `eret` 之後 PC 確實落在 `el1_entry`，但 `EL` 還是 2、`IL` 已經是 1。

**症狀相同時，去找那個會分岔的欄位。** 這是裸機除錯的基本手法。

`0x200` 也不是隨機的：例外向量表的基底在 `VBAR_EL1`，重置後是 0；
「同層、同步例外」的入口在基底 + `0x200`。那裡放的是 QEMU 的 device tree，
不是向量表 —— 向量表要到 M3 才建。

`make step3` 會印出來：

    0x0:    0xedfe0dd0    ← 一個 byte 一個 byte 讀是 d0 0d fe ed = "d00dfeed"
    0x200:  "020000"      ← device tree 的字串區

（`x` 指令印的是一個 32 位元的**數**，而 magic 在檔案裡是**四個 byte**，
所以顯示順序看起來是反的。不是跑錯了。）

step3 和 step8 還會各印一個 `ESR_EL1`（例外原因）—— 這就是那個「會分岔的欄位」：

    step3   ESR_EL1 = 0x96000040   EC = 0x25 (Data Abort)
            FAR_EL1 = 0xfffffffffffffff0                ← 正是 sp-16
    step8   ESR_EL1 = 0x2000000    EC = 0x00 (Unknown)

`ESR` = Exception Syndrome Register，硬體用它說明「為什麼會有這個例外」。
最有用的是 **EC 欄位（bits[31:26]）**，也就是例外的種類 —— `p/x $ESR_EL1 >> 26`。
`pc` 和 `EL` 一模一樣的兩個錯，就是靠這個欄位分開的。

## 為什麼要「先弄髒」

階梯 5 開機前會用 `-device loader` 往 `.bss` 塞 `0xcafe1234`。

因為 QEMU 給的新記憶體本來就是 0，**不弄髒的話，看到 0 什麼都證明不了**。

> 一個不可能失敗的實驗，不是實驗。
> 要問：**如果我的假設是錯的，這個實驗會給出不同的答案嗎？**

（`data-len` 最多只能填 7。填 8 會讓 QEMU 6.2 直接 assert 掛掉 ——
`s->data` 是 `uint64_t` 而比較寫的是嚴格小於。要一次弄髒 8 個 byte 得用 GDB。）

## 想自己在 GDB 裡面翻

`make` 的版本是跑完就走。要自己下指令的話：

```bash
cd lab/m1
./run.sh step9              # 先跑一次，順便編譯出 build/step9.elf
pkill -x qemu-system-aar    # 清場

qemu-system-aarch64 -M virt -cpu cortex-a72 -display none -serial none \
    -kernel build/step9.elf -S -s &
gdb-multiarch -q build/step9.elf -ex 'target remote :1234'
```

位址每一階都不一樣，先查再用：

```bash
aarch64-linux-gnu-nm build/step9.elf | grep -i 'kernel_main\|bss_start\|stack_top'
```

常用的 GDB 指令：

```
stepi                    走一條指令
stepi 4                  走四條
break *0x40000094        在某個位址停（星號 = 這是位址不是函式名）
break kernel_main        用符號停 —— 注意會跳過函式序言，SP 會少 16
continue                 跑到下一個斷點
p/x $pc                  現在站在哪
p/x $sp                  堆疊指標
p ($cpsr >> 2) & 3       我在第幾層
x/3i $pc                 往下看三條指令
x/s 0x200                把那個位址當字串印
p/x *(unsigned long *)<位址>        讀 8 個 byte（用上面查到的 __bss_start）
```

系統暫存器要用**大寫全名**：

```
p/x $ESR_EL1             例外原因
p/x $FAR_EL1             出事的位址
p/x $VBAR    $SCTLR      EL1 的這兩顆不帶 _EL1 後綴
p/x $TTBR0_EL1           但這種又要帶 —— 命名不一致，記不起來就查：
maint print remote-registers
```

**回 `void` 有三種原因（外加一顆本來就沒有的），別搞混：**

| 症狀 | 原因 |
|---|---|
| `p/x $hcr_el2` → `void` | 小寫。要打 `$HCR_EL2` |
| `p/x $VBAR_EL1` → `void` | 名字錯。EL1 這顆就叫 `$VBAR` |
| `p/x $HCR_EL2` → `void`，**用 `-M virt` 開機時** | **這台機器根本沒有 EL2** |
| `p/x $CurrentEL` → `void` | 真的沒有這顆。只能靠 `mrs` 讓程式自己讀 |

實測 `maint print remote-registers` 的數量會跟著機器變：

    -M virt                     383 顆
    -M virt,virtualization=on   411 顆

差額 28 是**淨值**：多了 29 顆 EL2 控制暫存器（`HCR_EL2`、`SPSR_EL2`、`VBAR_EL2`…），
但少了 1 顆 `RVBAR_EL1` —— QEMU 只在「最高的那一層」暴露 `RVBAR`。

（`-M virt` 下並不是完全沒有帶 `_EL2` 字樣的暫存器，`ACTLR_EL2` 等四顆還在也讀得到。
**「名字裡有 _EL2」跟「這台機器有 EL2」是兩件事。**）

> ⚠️ 清 QEMU 一律用 `pkill -x qemu-system-aar`。
> Linux 的行程名上限 15 字元，`qemu-system-aarch64` 有 19 個，用全名比對不到。
> 而 `pkill -f` 比對完整命令列，會**連跑這條指令的 shell 一起殺掉**。

## 幾個檔案的關係

- `step9.S` 與 `kernel/boot.S` **指令完全相同**，只差註解
- `start.c`、`kernel-qemu.ld` 是 **M1 當時的快照**，不跟著後面的里程碑走
- 想知道**為什麼**這樣寫（位元怎麼拆、哪些直覺是錯的），看
  `docs/guide/m1-boot-flow.html`

> `git log` 記結論，`docs/guide/` 講原理，`lab/` 讓你重新跑一遍。
