# PROJECT KNOWLEDGE BASE

## OVERVIEW
`cnn_ram` 是 Cortex-M0 + CNN 的软硬协同工程，包含 Vivado FPGA 工程与 Keil 固件工程两条链路。

## STRUCTURE
```
cnn_ram/
├── Vivado/CM0_Proj/              # FPGA 工程主目录（.xpr 入口）
│   ├── CM0_Proj.srcs/            # RTL/导入源
│   ├── CM0_Proj.runs/            # 综合布局布线输出（生成物）
│   └── CM0_Proj.sim/             # xsim 相关输出（生成物）
└── Keil/Keil_proj/               # 固件工程（UVPROJX）
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Vivado 工程入口 | `Vivado/CM0_Proj/CM0_Proj.xpr` | GUI 打开主入口 |
| CNN RTL 重点 | `Vivado/CM0_Proj/CM0_Proj.srcs/**/cnn_verilog/` | `conv*`, `fully_connected.v` |
| SoC 顶层 | `Vivado/CM0_Proj/CM0_Proj.srcs/**/new_rtl/CortexM0_SoC.v` | 系统总连接点 |
| Keil 固件入口 | `Keil/Keil_proj/USER/main.c` | 固件主流程 |
| 固件工程文件 | `Keil/Keil_proj/USER/WirelessMCU.uvprojx` | Keil 工程配置 |

## CONVENTIONS
- Vivado 与 Keil 是两套并行工程：RTL 改动后需关注固件接口是否同步。
- `CM0_Proj.srcs` 下文件可作为源码阅读入口；`*.runs/*.cache/*.sim` 主要是工具输出。
- 日志中存在批处理命令模板：`vivado -mode batch -source <tcl>`，可用于复现实验。
- 路径层级深且包含重复 `imports` 目录，脚本检索应优先按关键后缀（`cnn_verilog`, `new_rtl`）定位。

## ANTI-PATTERNS (THIS SUBPROJECT)
- 不要在 `CM0_Proj.runs/`, `CM0_Proj.cache/`, `CM0_Proj.sim/` 中手改生成文件。
- 不要把 `.bit/.dcp/.db/.log/.jou` 变更当作代码审查主体。
- 不要只改 FPGA 或只改固件就结束联调，寄存器/内存映射需双端一致。
- 不要假设 Vivado 日志里的本机绝对路径可直接复用到其他机器。

## COMMANDS
```bash
# 打开 Vivado 工程（GUI）
vivado "cnn_ram/Vivado/CM0_Proj/CM0_Proj.xpr"

# 参考日志中的 batch 模式（按实际 tcl 路径）
vivado -mode batch -source CortexM0_SoC.tcl
```

## NOTES
- 该目录生成物密集，做知识检索时建议先过滤 `*.runs`, `*.cache`, `*.sim`。
- 若需定位“可维护源码”，优先从 `CM0_Proj.srcs` 与 `Keil/Keil_proj/USER` 开始。
