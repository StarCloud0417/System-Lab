#!/usr/bin/env bash
#
# check-env.sh - 檢查建置與除錯所需的工具是否齊備。
#
# 為什麼需要這個腳本：本專案的文件裡有大量實測數值（ELF 大小、斷點位址、
# section 對齊），而這些數字會隨工具版本改變 —— ld 的孤兒 section 擺放規則、
# gdb 的 prologue 判斷、預設頁大小都是。版本不同時不會有任何錯誤訊息，
# 照著文件做的人只會發現數字對不上，卻不知道原因。
#
# 因此這裡的規則是：缺工具 = 失敗（exit 1），版本不同 = 只提醒（exit 0）。
# 版本不必一致也能把核心建出來，只是文件裡的數字要自己重新量。
#
# 不使用 set -e：工具不存在時要繼續檢查下去，一次列出所有缺的東西，
# 而不是每跑一次只噴一個。

# 必須跟 Makefile 的 CROSS 一致。有些發行版的裸機工具鏈叫 aarch64-none-elf-。
CROSS="${CROSS:-aarch64-linux-gnu-}"
# 去掉尾端空白。Makefile 的 `CROSS := 值   # 註解` 會把註解前的空白留在變數裡，
# 前綴一旦帶著空白，錯誤訊息會變成「找不到 aarch64-none-elf-   gcc」，
# 而那幾格空白在畫面上幾乎看不出來。
CROSS="${CROSS%"${CROSS##*[![:space:]]}"}"

# 本專案的文件與教材是在這組版本上量測的
REF_GCC="11.4.0"
REF_LD="2.38"
REF_QEMU="6.2.0"
REF_GDB="12.1"

missing=0
mismatch=0

# 取出版本號。每個工具的 --version 格式都不一樣，處理方式是先去掉括號內容
# （發行版常把另一組版本號塞在括號裡），再抓第一個長得像版本號的字串：
#   aarch64-linux-gnu-gcc (Ubuntu 11.4.0-...) 11.4.0  ->  11.4.0
#   QEMU emulator version 6.2.0 (Debian ...)          ->  6.2.0
#   Version: DTC 1.6.1                                ->  1.6.1
#
# 不取「最後一欄」：版本號後面未必是行尾，而且 --version 偶爾會混進警告訊息，
# 兩種情況都會讓最後一欄抓到不相干的字。抓第一個形如 N.N 的字串穩定得多。
#
# 回傳非 0 代表這個工具跑不起來（例如共享函式庫壞掉），呼叫端要當成缺工具處理 ——
# 對使用者而言「裝了但不能用」跟「沒裝」是同一件事。
version_of() {
    local out
    out="$("$@" --version 2>/dev/null)" || return 1
    printf '%s\n' "$out" | head -1 | sed 's/([^)]*)//g' \
        | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# $1=執行檔  $2=參考版本（空字串代表不比對）  $3=這個工具是幹嘛的
need() {
    local cmd="$1" ref="$2" purpose="$3" ver

    # command -v 是 shell 內建，找不到時回傳非 0。不用 which：
    # 它是外部程式，且在部分發行版找不到時仍回傳 0。
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf '  [缺少] %-26s %s\n' "$cmd" "$purpose"
        missing=$((missing + 1))
        return
    fi

    if ! ver="$(version_of "$cmd")" || [ -z "$ver" ]; then
        printf '  [損壞] %-26s 找得到但執行失敗，%s\n' "$cmd" "$purpose"
        missing=$((missing + 1))
        return
    fi

    if [ -n "$ref" ] && [ "$ver" != "$ref" ]; then
        printf '  [版本] %-26s %s（文件量測於 %s）\n' "$cmd" "$ver" "$ref"
        mismatch=$((mismatch + 1))
    else
        printf '  [就緒] %-26s %s\n' "$cmd" "$ver"
    fi
}

# 選配：缺了只影響單一功能，不算失敗
optional() {
    local cmd="$1" purpose="$2" ver

    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf '  [選配] %-26s 未安裝，%s\n' "$cmd" "$purpose"
        return
    fi

    if ! ver="$(version_of "$cmd")" || [ -z "$ver" ]; then
        printf '  [損壞] %-26s 找得到但執行失敗，%s\n' "$cmd" "$purpose"
        return
    fi
    printf '  [就緒] %-26s %s\n' "$cmd" "$ver"
}

echo "檢查工具鏈（CROSS=${CROSS}）"
echo

need "${CROSS}gcc" "$REF_GCC"  "交叉編譯器，建置核心"
# ld 不是由 Makefile 直接呼叫（連結是 gcc -Wl,-T 驅動的），但文件裡的
# 實測數值最依賴它的版本 —— 孤兒 section 的擺放規則就是 ld 決定的。
need "${CROSS}ld"       "$REF_LD" "連結器，決定載入位址"
need "${CROSS}objdump"  ""        "反組譯，make dump 會用"
need "${CROSS}readelf"  ""        "讀 ELF header，make dump 會用"
need "qemu-system-aarch64" "$REF_QEMU" "模擬器，執行核心"
need "gdb-multiarch" "$REF_GDB" "除錯器，驗證 CPU 是否在執行"
optional "dtc" "make dtb 會不能用"
# make debug 用 ss 檢查 port 1234 有沒有被佔用。缺了不會報錯，那道守衛會
# 安靜地失效，然後 GDB 可能連上前一隻沒關乾淨的 QEMU。
optional "ss"  "make debug 的 port 守衛會失效"

echo
if [ "$missing" -gt 0 ]; then
    echo "缺少 ${missing} 個必要工具。"
    if [ "$CROSS" = "aarch64-linux-gnu-" ]; then
        echo "Ubuntu / Debian 上："
        echo
        echo "  sudo apt install gcc-aarch64-linux-gnu qemu-system-arm \\"
        echo "                   gdb-multiarch device-tree-compiler iproute2"
    else
        echo "工具鏈前綴是 ${CROSS}，這不是發行版套件提供的名稱，"
        echo "請確認該工具鏈已安裝且在 PATH 上（或改回 Makefile 的預設值）。"
    fi
    exit 1
fi

if [ "$mismatch" -gt 0 ]; then
    echo "工具齊備。有 ${mismatch} 個版本與文件不同，核心照樣建得起來，"
    echo "但 docs/guide/ 裡的實測數值（ELF 大小、斷點位址等）請自己重新量。"
else
    echo "工具齊備，版本與文件一致。"
fi
exit 0
