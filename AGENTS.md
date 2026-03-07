# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-26 02:24 (Asia/Shanghai)
**Commit:** 696c26a
**Branch:** main

## OVERVIEW
个人 FPGA 学习仓库，主体是 01~17 编号递进的 Verilog 练习模块；同时包含竞赛项目 `18. 2025-fpga-anlogic-audio` 与 `cnn_ram` 工程。

## STRUCTURE
```
FPGA/
├── 01. mux2 ... 17. apb/       # 学习主线模块（核心）
├── 18. 2025-fpga-anlogic-audio/# 安路音频竞赛项目（独立子体系）
├── cnn_ram/                     # Cortex-M0 + CNN 工程（Vivado/Keil）
├── portfolio/                   # 作品集与验证计划文档
├── README.md                    # 总入口
└── opencode.json                # 本仓库命令模板与忽略规则
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| 新建学习模块 | `0X. */` | 默认 `module.v + module_tb.v (+.xdc)` |
| APB 学习/调试 | `17. apb/` | `apb_slave.v` + `APB_Protocol_Guide.md` |
| Verilog 风格规则 | `AGENTS.md`, `.opencode/skills/verilog-style/SKILL.md` | 以本仓库规则优先 |
| 仿真命令参考 | `.opencode/skills/fpga-debug/SKILL.md`, `portfolio/week0-baseline.md` | `iverilog/vvp/gtkwave` 可用 |
| 安路音频项目 | `18. 2025-fpga-anlogic-audio/` | 有独立 README 与工程结构 |
| Vivado 工程入口 | `cnn_ram/Vivado/CM0_Proj/CM0_Proj.xpr` | 含大量生成物，谨慎遍历 |

## CONVENTIONS
- 命名：模块 `module_name.v`，仿真 `module_name_tb.v`，约束 `module_name.xdc`。
- 风格：2 空格缩进；优先低有效异步复位 `rst_n`；状态机三段式；参数全大写。
- 注释：中文注释。
- TB 发现规则：优先 `*_tb.v`，兼容少量 `tb_*.v`（如 `09. gray_converter/tb_gray_converter.v`）。
- XDC 发现规则：优先同名 `.xdc`，兼容别名（如 `01. mux2/mux_2.xdc`）。

## ANTI-PATTERNS (THIS PROJECT)
- 不要把 `*.vcd`, `*.vvp`, `*.log`, `*.jou`, `*.db`, `*.bit` 当作源码修改目标。
- 不要假设文件名一定等于模块名：以 `module ...` 声明为准。
- 不要把 APB `ACCESS` 判定写成仅 `PSEL=1`；本仓库约定 `PSEL && PENABLE` 才是有效访问。
- 不要默认所有目录都适合细粒度知识库：`cnn_ram/Vivado`、`*.runs`、`.venv` 属生成物密集区。

## UNIQUE STYLES
- 学习主线是“编号模块逐步递进”，非典型单应用仓库。
- 同仓混合三类内容：学习模块、竞赛工程、作品集/规划文档。
- `17. apb/apb_slave.v` 明确无等待周期示例：`PREADY=1`、`PSLVERR` 仅 ACCESS 有效。

## COMMANDS
```bash
# 单模块仿真（示例）
iverilog -g2012 -s <tb_module> -o sim.out <dut.v> <tb.v>
vvp sim.out
gtkwave <wave.vcd>

# Vivado 工程（GUI）
vivado cnn_ram/Vivado/CM0_Proj/CM0_Proj.xpr
```

## NOTES
- `18. 2025-fpga-anlogic-audio` 下有独立 `.git` 与子项目约定，先读其 `README.md`。
- 目录名含空格与中文，脚本命令必须全程加引号。
- `opencode.json` 已声明 watcher 忽略规则：`.Xil/**`, `impl_*/**`, `synth_*/**`, `*.log` 等。
