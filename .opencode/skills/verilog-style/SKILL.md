---
name: verilog-style
description: Verilog/SystemVerilog coding style guide for FPGA and digital IC design. Use when writing, reviewing, or refactoring Verilog RTL code.
license: MIT
compatibility: opencode
metadata:
  domain: hardware
  language: verilog
---

# Verilog 编码规范 Skill

## 适用场景

当你需要：
- 新建 Verilog 模块
- 代码审查 / 重构
- 解释或改进已有 RTL 代码

## 模块头注释模板

每个 `.v` 文件必须包含如下头注释：

```verilog
`timescale 1ns / 1ps
// 模块: <module_name>
// 说明: <功能描述>
// 主要参数:
//  - PARAM_A: 说明
// 主要端口:
//  - clk / rst_n: 时钟与复位
//  - input_xxx:   输入说明
//  - output_xxx:  输出说明
// 备注:
//  - <设计注意事项>
// -----------------------------------------------------------------------------
```

## 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 模块名 | 小写+下划线 | `async_fifo`, `apb_slave` |
| 时钟信号 | `clk` / `xxxclk` | `wrclk`, `rdclk` |
| 复位信号 | `rst_n`（低有效）/ `reset`（高有效）| `rst_n`, `reset` |
| 寄存器 | `_r` 后缀（可选）| `data_r` |
| 组合逻辑 | `_next` / `_comb` | `state_next` |
| 参数 | 全大写+下划线 | `DATA_WIDTH`, `ADDR_WIDTH` |
| 格雷码信号 | `_gray` 后缀 | `wr_pntr_gray` |
| 跨时钟域 | `wrside_` / `rdside_` 前缀 | `wrside_rd_pntr_bin` |

## 复位规范

```verilog
// ✅ 推荐：异步复位，同步释放（FPGA 通用）
always @(posedge clk or negedge rst_n)
    if (!rst_n)
        q <= 'd0;
    else
        q <= d;

// ✅ 高电平复位（IC 常用）
always @(posedge clk or posedge reset)
    if (reset)
        q <= 'd0;
    else
        q <= d;

// ❌ 避免：在 always 块中混用多种复位
```

## 状态机规范（三段式）

```verilog
// 第一段：状态寄存器（时序逻辑）
always @(posedge clk or negedge rst_n)
    if (!rst_n) state <= IDLE;
    else        state <= state_next;

// 第二段：次态逻辑（组合逻辑）
always @(*) begin
    state_next = state;  // 默认保持
    case (state)
        IDLE: if (start) state_next = WORK;
        WORK: if (done)  state_next = IDLE;
    endcase
end

// 第三段：输出逻辑（组合或时序）
always @(*) begin
    out = 1'b0;   // 默认值，防止 latch
    case (state)
        WORK: out = 1'b1;
    endcase
end
```

## 跨时钟域（CDC）规范

```verilog
// 单 bit CDC：打两拍同步
always @(posedge dst_clk or negedge rst_n)
    if (!rst_n) {sync2, sync1} <= 2'b0;
    else        {sync2, sync1} <= {sync1, src_signal};

// 多 bit CDC：必须使用格雷码（见 async_fifo 实现）
// 禁止：直接将多 bit 二进制直接跨时钟域传输
```

## 综合友好写法

```verilog
// ✅ 推荐：参数化
module my_module #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout
);

// ✅ 推荐：明确位宽
assign full = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
              (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

// ❌ 避免：隐式位宽截断
// ❌ 避免：在组合逻辑中使用不完整的 case（会产生 latch）
// ❌ 避免：阻塞赋值（=）用于时序逻辑
// ❌ 避免：非阻塞赋值（<=）用于组合逻辑
```

## 文件结构规范

```
XX. <module_name>/
├── <module_name>.v       # 主模块
├── <module_name>_tb.v    # Testbench
└── (可选) sub_module.v   # 子模块
```

## 代码审查检查点

在提交代码前，确认：

- [ ] 所有 `always` 块都有完整的敏感信号列表（或用 `*`）
- [ ] 组合逻辑 `case` 有 `default` 分支
- [ ] 没有多驱动（multiple driver）问题
- [ ] 参数全部大写
- [ ] 跨时钟域信号已打两拍同步
- [ ] 复位信号覆盖所有寄存器初始值
