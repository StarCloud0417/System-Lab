# lab/m2 —— 用實驗驗證 M2 教材裡的每一條宣稱
#
# 前八階每一階都在問「這樣東西是必要的嗎」，第九階是答案。

STEPS := step1 step2 step3 step4 step5 step6 step7 step8 step9

.PHONY: help all clean $(STEPS)

help:
	@echo "驗證 M2 教材。照順序跑，每一階都在問「這樣東西是必要的嗎」。"
	@echo
	@echo "  make step1   完全不初始化，直接寫 DR —— 會有輸出嗎"
	@echo "  make step2   開機時 PL011 的六個暫存器（UARTEN 是 0）"
	@echo "  make step3   用 C 寫最小 putc：沒 init、沒 volatile、沒等待"
	@echo "  make step4   volatile 在 -O0 下有差別嗎 —— 沒有"
	@echo "  make step5   volatile 在 -O2 下救了哪一條指令   ★ 重點"
	@echo "  make step6   鮑率：捨去 vs 四捨五入，在哪個時脈分岔"
	@echo "  make step7   CR/LF 放在 uart_puts 裡的後果"
	@echo "  make step8   TXFF 等待迴圈跑了幾圈 —— 0 圈"
	@echo "  make step9   完整版，與 drivers/uart/pl011.c 相同"
	@echo
	@echo "  make all     一口氣跑完"
	@echo "  make clean"

$(STEPS):
	@./run.sh $@

all: $(STEPS)

clean:
	rm -rf build
