# 第七章 RISC-V 单周期教学核

## 工程目标

本工程把《数字设计和计算机体系结构（RISC-V 版）》第 7.6 节的单周期处理器整理为一个可阅读、可编译、可自动测试的模块化 SystemVerilog 工程。

这里的“完整”是指教材单周期数据通路和控制器的完整实现，不是完整 RV32I 产品级处理器。核心不包含异常、中断、CSR、缓存、总线和调试接口。

## 支持的指令

| 指令类型 | 指令 | 主要数据流 |
|---|---|---|
| R-type | `add/sub/slt/or/and` | `rs1, rs2 → ALU → rd` |
| I-type | `addi/slti/ori/andi` | `rs1, imm → ALU → rd` |
| Load | `lw` | `rs1 + imm → 数据存储器 → rd` |
| Store | `sw` | `rs1 + imm → 地址`，`rs2 → 写数据` |
| Branch | `beq` | `rs1-rs2 → Zero`，满足条件时 `PC ← PC+imm` |
| Jump | `jal` | `rd ← PC+4`，同时 `PC ← PC+imm` |

未实现或非法编码不会写寄存器、不会写数据存储器，也不会跳转；PC 按 `PC+4` 前进。这只是教学用的安全退化行为，不等价于 RISC-V 非法指令异常。

## 如何理解模块层次

```text
rv32_core
├── rv32_controller
│   ├── rv32_main_decoder
│   └── rv32_alu_decoder
└── rv32_datapath
    ├── rv32_pc
    ├── rv32_regfile
    ├── rv32_imm_ext
    ├── rv32_alu
    ├── rv32_adder × 2
    ├── rv32_mux2 × 2
    └── rv32_mux3
```

可以把整个核心看成两部分：

- 数据通路保存并搬运数据。真正的体系结构状态是 PC、寄存器堆，以及核心外部的数据存储器。
- 控制器观察 `opcode/funct3/funct7`，决定本周期允许哪些状态写入，以及各个 MUX 选择哪条数据流。

单周期并不表示组合逻辑没有传播时间。一个 `lw` 周期内，信号需要经过：

```text
PC → 指令存储器 → 寄存器堆/立即数扩展
   → ALU 地址计算 → 数据存储器 → 写回 MUX → 寄存器堆写端口
```

下一个时钟沿到来前，整条路径必须稳定，因此 `lw` 通常构成本设计的关键路径。

## 核心接口

```systemverilog
module rv32_core (
  input  logic        clk_i,
  input  logic        rst_n_i,

  output logic [31:0] imem_addr_o,
  input  logic [31:0] imem_rdata_i,

  output logic [31:0] dmem_addr_o,
  output logic [31:0] dmem_wdata_o,
  output logic        dmem_we_o,
  input  logic [31:0] dmem_rdata_i
);
```

- `imem_addr_o` 是当前 PC，也是字节地址。
- `dmem_addr_o` 是 ALU 计算出的有效字节地址。
- `dmem_wdata_o` 始终来自寄存器 `rs2`。
- `dmem_we_o` 仅在有效 `sw` 指令周期拉高。
- `rst_n_i` 是低有效异步复位，只复位 PC。寄存器堆不整体复位，`x0` 通过读旁路和写抑制保持为零。

## 存储器时序契约

`rv32_core` 假定指令存储器和数据存储器均为组合读，数据存储器在时钟上升沿同步写。`sim` 目录中的模型实现了这个契约：

```text
组合读：地址变化 → 同一周期内读数据变化
同步写：dmem_we_o=1 → 下一个上升沿把写数据提交到存储阵列
```

这是教材单周期处理器能够让 `lw` 在一个周期完成的前提。多数 FPGA Block RAM 使用同步读接口，不能直接替换这里的组合读模型；若要使用同步 BRAM，应改成多周期或流水线微体系结构。

当前只支持 4 字节对齐的 `lw/sw`。存储器模型用地址的 `[7:2]` 作为 64×32 位数组下标，没有实现字节写使能、非对齐访问检测或访问异常。

## 仿真

在工程目录中运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_all.ps1
```

脚本依次运行 ALU、立即数扩展、寄存器堆、译码器和整机测试。编译产物放在系统临时目录，不写入工程。

整机测试加载 `programs/riscvtest.hex`。教材程序端到端覆盖 `add/sub/and/or/slt/addi/lw/sw/beq/jal`，先把 `7` 写入地址 `96`，最后把 `25` 写入地址 `100`；任何意外写地址、错误写数据或超时都会令测试失败。`slti/ori/andi` 与 `addi` 复用同一条 I-type 数据通路，其功能选择由译码器测试和 ALU 测试分别覆盖。

## 阅读建议

建议按以下顺序阅读代码：

1. `rv32_pc.sv`：先确认处理器最基本的时序状态。
2. `rv32_regfile.sv`：理解两读一写和 `x0` 固定为零。
3. `rv32_imm_ext.sv`：对照 I/S/B/J 型机器码字段。
4. `rv32_alu.sv`：确认每个 ALU 控制码综合出的运算。
5. `rv32_datapath.sv`：沿着一条指令的数据流追踪各模块。
6. `rv32_main_decoder.sv` 与 `rv32_alu_decoder.sv`：从写使能和 MUX 反推控制条件。
7. `rv32_core.sv`：最后观察控制器与数据通路如何组合。

工程中的中文注释主要说明信号为何存在、会综合出什么硬件，以及组合逻辑和时序状态的边界。
