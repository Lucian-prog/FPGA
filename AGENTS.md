# FPGA PROJECT INSTRUCTIONS

## OVERVIEW

个人 FPGA 与数字 IC 前端学习仓库，主体为 `01`～`23` 编号递进的 Verilog/SystemVerilog/Cocotb 练习模块；同时包含竞赛项目 `18. 2025-fpga-anlogic-audio`、`cnn_ram` 软硬件协同工程，以及 `Bagu`/`uvm_learn` 两个专题学习目录。

## STRUCTURE

```text
FPGA/
├── 01. mux2 ... 17. apb/        # Verilog 学习主线
├── 18. 2025-fpga-anlogic-audio/ # 安路音频竞赛项目（独立子体系）
├── 19. SV_Blocks/               # SystemVerilog 模块练习
├── 20. RV32I_Core/              # RISC-V 五级流水处理器
├── 21. AMBA_Bus/                # AHB-Lite / AXI-Lite 从机练习
├── 22. dma_ctrl/                # AXI DMA 控制器（RTL+TB+SVA）
├── 23. cocotb/                  # Cocotb Python 协同仿真入门
├── Bagu/                        # 面试手撕练习（复位同步/时钟切换/FIFO/握手）
├── uvm_learn/                   # 《UVM实战》学习仓（VCS 实跑）
├── cnn_ram/                     # Cortex-M0 + CNN 工程（Vivado/Keil）
└── README.md                    # 总入口
```

> `rtl-agent/` 是带独立 `.git` 的自研 Python 工具仓，`_K3_review/` 为一次性评审材料，
> 两者连同各 EDA 生成物目录均已被根 `.gitignore` 排除，不属于仓库内容。

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| 新建学习模块 | `0X. */`、`19. SV_Blocks/` | 默认 `module.v + module_tb.v (+ .xdc)` |
| APB 学习/调试 | `17. apb/` | `apb_slave.v` + `APB_Protocol_Guide.md` |
| 异步 FIFO/CDC | `16. async_fifo/` | 包含 FIFO、脉冲同步与 CDC 学习内容 |
| RISC-V 处理器 | `20. RV32I_Core/` | `filelist.f` + `scripts/run_all.ps1` |
| AMBA 从机 | `21. AMBA_Bus/` | AHB-Lite/AXI-Lite 从机 + `AMBA_总线协议详解.md` |
| DMA 控制器 | `22. dma_ctrl/` | `scripts/run.sh`（VCS）+ SVA 全绿 |
| Cocotb 入门 | `23. cocotb/` | `counter/` 示例 + 入门学习指南 |
| 面试手撕 | `Bagu/` | 每个子目录 RTL+TB+README |
| 安路音频项目 | `18. 2025-fpga-anlogic-audio/` | 先读该目录的 `README.md` |
| Vivado 工程入口 | `cnn_ram/Vivado/CM0_Proj/CM0_Proj.xpr` | 遵守 `cnn_ram/AGENTS.md` |

## RTL ASSISTANCE RULES

### 1. 先理解需求

- 明确模块功能、时钟、复位、接口、数据宽度、时序要求和边界条件。
- 信息不足时，优先根据现有上下文做合理假设并明确列出。
- 只有缺失信息会直接导致设计方案完全不同时，才向主人提问。

### 2. 坚持硬件思维

- 将 Verilog/SystemVerilog 视为硬件描述，而不是普通软件程序。
- 解释代码会综合成什么寄存器、组合逻辑、选择器、计数器或状态机。
- 注意并行执行、时钟边沿、组合路径、寄存器延迟、扇出和资源占用。

### 3. 默认提供可综合 RTL

- 除非明确要求 testbench、验证代码或纯仿真模型，否则代码必须可综合。
- 避免锁存器、组合环路、多驱动、未定义信号及不可综合结构。
- 明确区分组合逻辑与时序逻辑。
- SystemVerilog 优先合理使用 `logic`、`always_ff`、`always_comb`、参数和枚举状态。
- Verilog 保持清楚、规范，并兼容现有工程的语言版本。

### 4. 重视时序、复位与 CDC

- 明确同步复位和异步复位的区别，检查复位释放风险。
- 不将普通逻辑信号直接作为时钟。
- 多时钟域设计必须分析亚稳态、脉冲宽度和目标域漏采风险。
- 根据场景选择双触发器同步、握手、脉冲同步或异步 FIFO。
- 检查数据与控制信号的流水线延迟是否对齐。

### 5. 主动检查常见错误

- 时序逻辑使用非阻塞赋值，组合逻辑使用阻塞赋值。
- 检查位宽、符号扩展、截断、溢出和参数边界。
- 检查 `case` 完整性、默认分支、计数器上下界和状态跳转。
- 检查同一信号是否被多个过程块驱动。
- 检查 valid/ready、请求/应答等握手条件是否会重复触发或丢失。

### 6. 修改现有工程时保持克制

- 先阅读现有代码结构、模块声明和命名习惯。
- 尽量最小修改，不重构与当前问题无关的部分。
- 不擅自改变模块接口、时钟极性、复位方式或协议行为。
- 修改后说明变更原因、影响范围和验证结果。

## CONVENTIONS

- 命名：模块文件优先 `module_name.v`，仿真优先 `module_name_tb.v`，约束优先 `module_name.xdc`。
- 文件名不一定等于模块名；编译顶层以 `module ...` 声明为准。
- 缩进：2 空格。
- 复位：遵循现有模块；新学习模块优先低有效异步复位 `rst_n`。
- 状态机：优先三段式；参数和常量使用大写名称，避免无解释的魔法数字。
- 注释：以必要的中文注释为主，不逐行添加无意义注释。
- 信号后缀：`_i` 输入、`_o` 输出、`_n` 低有效、`_d` 下一值、`_q` 寄存器当前值。
- 位选择：边界为常量时禁用 indexed part-select（`-:`/`+:`），一律写普通 `[msb:lsb]`（例：`[PHASE_W-1 -: LUT_AW]` 应写成 `[PHASE_W-1:PHASE_W-LUT_AW]`）；仅循环内变量起点切片（如 `[8*i +: 8]`）允许保留 `+:`，因为普通位选择不支持变量边界。
- TB 发现：优先 `*_tb.v`，兼容 `tb_*.v`。
- XDC 发现：优先同名 `.xdc`，兼容已有别名。

## PROJECT-SPECIFIC BEHAVIOR

- APB 有效 ACCESS 阶段必须使用 `PSEL && PENABLE` 判定，不能仅使用 `PSEL`。
- `17. apb/apb_slave.v` 是无等待周期示例：`PREADY=1`，`PSLVERR` 仅在 ACCESS 阶段有效。
- `18. 2025-fpga-anlogic-audio` 已作为普通目录纳入本仓库；竞赛原仓库（github.com/Lucian-prog/2025-fpga-anlogic-audio-solution）保留独立历史，进入后先阅读其 README。
- `cnn_ram` 的寄存器或内存映射修改必须同步检查 RTL 与 Keil 固件。

## GENERATED FILES AND SEARCH BOUNDARIES

- 不把 `*.vcd`、`*.vvp`、`*.log`、`*.jou`、`*.db`、`*.bit`、`*.dcp` 当作源码修改目标。
- 上述生成物已由根 `.gitignore` 排除出版本控制，本地文件保留，无需手动清理。
- 不手工修改 `.Xil/`、`*.runs/`、`*.cache/`、`*.sim/`、`.venv/` 中的生成文件。
- 遍历 Vivado 工程时优先定位 `*.srcs` 源码目录，避免无边界递归生成物目录。
- 目录名含空格与中文，PowerShell 和脚本命令中的路径必须完整加引号。
- 保留主人已有的未提交改动，不清理、不回退与当前任务无关的文件。

## VERIFICATION

- 修改 RTL 后，优先运行对应模块的 `*_tb.v` 或 `tb_*.v`。
- 使用 `iverilog -g2012 -s <tb_module>` 明确指定测试顶层，避免误选 DUT 为顶层。
- 仿真输出写入临时目录或明确忽略的构建目录，不提交生成的波形和编译产物。
- 协议模块至少验证正常传输、背压/等待、复位中止、连续传输和非法访问等适用场景。
- FIFO/CDC 至少验证复位、空满边界、指针回绕、快到慢、慢到快以及异步相位关系。
- 修改接口后检查所有例化端口、位宽、符号属性、复位极性和控制/数据延迟对齐。
- 未实际运行仿真、综合、形式验证或上板时，必须明确标注为静态分析结果。

单模块仿真参考：

```powershell
$sim = Join-Path $env:TEMP "fpga_sim.vvp"
iverilog -g2012 -s <tb_module> -o $sim "<dut.v>" "<tb.v>"
vvp $sim
```

Vivado GUI 工程入口：

```powershell
vivado "cnn_ram/Vivado/CM0_Proj/CM0_Proj.xpr"
```

## REVIEW OUTPUT ORDER

代码审查优先报告：

1. 明确的功能错误。
2. 仿真与综合不一致风险。
3. 时序、复位与 CDC 风险。
4. 位宽、符号和边界问题。
5. 可读性和工程规范问题。

每个问题应指出具体位置、触发条件、硬件后果和修改方法；不要只说“代码有问题”。
