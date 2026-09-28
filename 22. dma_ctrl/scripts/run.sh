#!/usr/bin/env bash
#==============================================================================
# DMA 控制器一键回归
#   [1/2] tb_dma_regs —— P1 寄存器组自检（37 检查项）
#   [2/2] tb_dma_full —— P2~P4 顶层端到端（45 检查项 + 8 条属性检查）
# 仿真产物写入 sim_tmp/（不入库）。依赖：iverilog（-g2012）。
#==============================================================================
set -e
cd "$(dirname "$0")/.."
mkdir -p sim_tmp

RTL_REGS="rtl/dma_pkg.sv rtl/dma_fifo.sv rtl/dma_regs.sv"
RTL_ALL="rtl/dma_pkg.sv rtl/dma_fifo.sv rtl/dma_regs.sv \
         rtl/axi_rd_ch.sv rtl/axi_wr_ch.sv rtl/dma_ctrl.sv rtl/dma_top.sv"

echo "=== [1/2] tb_dma_regs (P1) ==="
iverilog -g2012 -s tb_dma_regs -o sim_tmp/tb_regs.vvp \
  $RTL_REGS tb/axi_lite_bfm.sv tb/tb_dma_regs.sv
vvp sim_tmp/tb_regs.vvp 2>/dev/null | grep -E "Summary|FINISH"

echo "=== [2/2] tb_dma_full (P2-P4 + SVA) ==="
iverilog -g2012 -s tb_dma_full -o sim_tmp/tb_full.vvp \
  $RTL_ALL tb/axi_lite_bfm.sv tb/axi_mem_slave.sv tb/dma_sva.sv tb/tb_dma_full.sv
vvp sim_tmp/tb_full.vvp 2>/dev/null | grep -E "Summary|FINISH|SVA"

echo "=== regression done ==="
