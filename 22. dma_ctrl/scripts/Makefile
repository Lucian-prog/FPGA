#==============================================================================
# DMA 控制器回归 Makefile（与 run.sh 等价，供装有 make 的环境使用）
#   make / make all  —— 全量回归（regs + full）
#   make regs        —— 仅 P1 寄存器 TB
#   make full        —— 仅顶层端到端 TB（含 SVA）
#   make clean       —— 清理仿真产物
#==============================================================================
RTL_REGS := rtl/dma_pkg.sv rtl/dma_fifo.sv rtl/dma_regs.sv
RTL_ALL  := rtl/dma_pkg.sv rtl/dma_fifo.sv rtl/dma_regs.sv \
            rtl/axi_rd_ch.sv rtl/axi_wr_ch.sv rtl/dma_ctrl.sv rtl/dma_top.sv

.PHONY: all regs full clean

all: regs full

regs: sim_tmp/tb_regs.vvp
	vvp sim_tmp/tb_regs.vvp 2>/dev/null | grep -E "Summary|FINISH"

full: sim_tmp/tb_full.vvp
	vvp sim_tmp/tb_full.vvp 2>/dev/null | grep -E "Summary|FINISH|SVA"

sim_tmp/tb_regs.vvp: $(RTL_REGS) tb/axi_lite_bfm.sv tb/tb_dma_regs.sv
	@mkdir -p sim_tmp
	iverilog -g2012 -s tb_dma_regs -o $@ $^

sim_tmp/tb_full.vvp: $(RTL_ALL) tb/axi_lite_bfm.sv tb/axi_mem_slave.sv tb/dma_sva.sv tb/tb_dma_full.sv
	@mkdir -p sim_tmp
	iverilog -g2012 -s tb_dma_full -o $@ $^

clean:
	rm -rf sim_tmp
