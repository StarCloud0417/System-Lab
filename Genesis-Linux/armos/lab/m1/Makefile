# lab/m1 —— 從零疊出 boot.S 的九階實驗
#
# 每一階都是被上一階的失敗逼出來的。照順序跑。

STEPS := step1 step2 step3 step4 step5 step6 step7 step8 step9 step9-el2

.PHONY: help all clean $(STEPS) vbar norw

help:
	@echo "從零疊出 boot.S。照順序跑，每一階都看得到上一階為什麼不夠。"
	@echo
	@echo "  make step1      最小核心 —— CPU 有跑到我的程式嗎"
	@echo "  make step2      我在哪一層 —— CurrentEL 是 0x4 還是 0x8"
	@echo "  make step3      直接呼叫 C —— 沒堆疊，炸到 0x200"
	@echo "  make step4      給它堆疊 —— 活了"
	@echo "  make step5      清 .bss —— 開機前先弄髒，實驗才可能失敗"
	@echo "  make step6      同一份 step5 改用 EL2 開機 —— 不炸，但層級錯了"
	@echo "                  （卡在「EL2 權限更高為什麼還算錯」就先跑 make vbar）"
	@echo "  make step7      降到 EL1 —— 盯著 eret 那一刻"
	@echo "  make step8      同一份 step7 改用一般開機 —— 又炸到 0x200"
	@echo "  make step9      先問層級再決定 —— 這就是 kernel/boot.S"
	@echo "  make step9-el2  同一個 step9 換 EL2 開機 —— 三個數字一字不差"
	@echo
	@echo "  make vbar       VBAR_EL1 和 VBAR_EL2 是兩顆不同的暫存器 —— 階梯 6 的佐證"
	@echo "  make norw       第三種 0x200 —— eret 跑了，但層級沒換"
	@echo "  make all        一口氣跑完全部"
	@echo "  make clean"
	@echo
	@echo "想自己在 GDB 裡面翻，看 README.md 最後一節。"

$(STEPS) vbar norw:
	@./run.sh $@

all: $(STEPS) vbar norw

clean:
	rm -rf build
