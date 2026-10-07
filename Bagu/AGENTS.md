# Bagu 目录约定

- 本目录及子目录默认不使用 `run-rtl-agent-toolchain` 技能或 `rtl-agent` MCP 工具；仅在主人明确要求使用时启用。
- RTL 审查直接阅读代码、分析硬件结构和逐拍行为；需要验证时可直接调用本地 Icarus Verilog 或 Verilator，不自动进入 RTL-Agent 报告与修复工作流。
