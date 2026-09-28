# FPGA

个人 FPGA 与数字 IC 前端学习仓库，按编号递进：从 Verilog 基础模块到总线、处理器与验证方法学。

## 目录

| 编号 | 主题 | 说明 |
|------|------|------|
| 01 ~ 17 | Verilog 学习主线 | mux2 → decoder → UART/SPI/I2C/CRC → async_fifo/CDC → APB |
| 18 | [2025-fpga-anlogic-audio](18.%202025-fpga-anlogic-audio) | 安路 FPGA 创新设计大赛项目（独立子体系） |
| 19 | [SV_Blocks](19.%20SV_Blocks) | SystemVerilog 模块练习 |
| 20 | [RV32I_Core](20.%20RV32I_Core) | RISC-V 五级流水处理器（RTL + TB） |
| 21 | [AMBA_Bus](21.%20AMBA_Bus) | AHB-Lite / AXI-Lite 从机 + 协议详解笔记 |
| 22 | [dma_ctrl](22.%20dma_ctrl) | AXI DMA 控制器（RTL + TB + SVA） |
| 23 | [cocotb](23.%20cocotb) | Cocotb Python 协同仿真入门 |
| — | [Bagu](Bagu) | 面试手撕练习（复位同步 / 时钟切换 / 序列检测 / 同步 FIFO / 握手） |
| — | [uvm_learn](uvm_learn) | 《UVM实战》学习仓（VCS 实跑记录） |
| — | [cnn_ram](cnn_ram) | Cortex-M0 + CNN 加速器 SoC 工程（Vivado/Keil） |

## 约定

- 目录命名 `NN. 名称`；RTL/TB 命名、编码风格、仿真流程见 [AGENTS.md](AGENTS.md)。
- 波形、编译产物等生成物不入库（`.gitignore` 已覆盖）。
- 仿真参考：`iverilog -g2012`（Windows）与 VCS（Rocky VM）双环境。
