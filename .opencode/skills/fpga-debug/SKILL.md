---
name: fpga-debug
description: FPGA and Verilog simulation debugging guide. Use when analyzing waveforms, fixing simulation failures, or diagnosing RTL behavior issues.
license: MIT
compatibility: opencode
metadata:
  domain: hardware
  phase: debug
---

# FPGA/Verilog 调试 Skill

## 适用场景

- 仿真波形与预期不符
- 模块功能验证失败
- 时序问题（建立时间/保持时间）
- 跨时钟域问题
- 综合/实现告警处理

---

## Testbench 标准模板

```verilog
`timescale 1ns / 1ps

module <module_name>_tb;

// ── 参数 ──────────────────────────────────
parameter CLK_PERIOD = 10;   // 100MHz

// ── 信号定义 ──────────────────────────────
reg  clk;
reg  rst_n;
// ... 根据 DUT 端口添加

// ── DUT 例化 ──────────────────────────────
<module_name> #(
    .PARAM_A (VALUE_A)
) uut (
    .clk   (clk),
    .rst_n (rst_n)
    // ...
);

// ── 时钟生成 ──────────────────────────────
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// ── 复位序列 ──────────────────────────────
initial begin
    rst_n = 0;
    repeat(5) @(posedge clk);   // 保持5个周期复位
    @(negedge clk);              // 在下降沿释放（避免建立时间冲突）
    rst_n = 1;
end

// ── 激励 ──────────────────────────────────
initial begin
    // 等待复位完成
    wait(rst_n == 1);
    repeat(2) @(posedge clk);

    // TODO: 添加测试激励

    // 仿真结束
    repeat(10) @(posedge clk);
    $display("PASS: Simulation finished at time %0t", $time);
    $finish;
end

// ── 超时保护 ──────────────────────────────
initial begin
    #(CLK_PERIOD * 10000);
    $display("TIMEOUT: Simulation exceeded limit");
    $finish;
end

// ── 波形转储 ──────────────────────────────
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, <module_name>_tb);
end

endmodule
```

---

## 常见问题排查

### 1. 输出一直为 X（不定态）

**原因**：未初始化、多驱动、组合逻辑环路

```verilog
// 检查点：
// ① 复位是否覆盖所有寄存器
// ② 是否有 wire 被多个 always 驱动
// ③ assign 中是否有未定义信号
```

### 2. 满/空标志错误（FIFO 类模块）

```verilog
// 检查格雷码同步方向是否正确：
// wr_pntr → 同步到读时钟域 → 与 rd_pntr 比较 → empty
// rd_pntr → 同步到写时钟域 → 与 wr_pntr 比较 → full
```

### 3. 状态机卡死

```verilog
// 检查点：
// ① default 分支是否设置回 IDLE
// ② 跳转条件是否互斥
// ③ 输入信号是否已同步到本时钟域
```

### 4. 综合产生 Latch

```
WARNING: Inferred latch for signal 'xxx'
```

```verilog
// 原因：组合逻辑 case 缺少 default，或 if 没有 else
// 修复：
always @(*) begin
    out = 'd0;   // ✅ 先赋默认值
    case (sel)
        2'b00: out = a;
        2'b01: out = b;
        default: out = 'd0;  // ✅ 必须有 default
    endcase
end
```

### 5. 时钟域交叉（CDC）亚稳态

```
CRITICAL WARNING: ... clock domain crossing
```

```verilog
// 标准处理：对单 bit 信号打两拍
reg sync1, sync2;
always @(posedge dst_clk or negedge rst_n)
    if (!rst_n) {sync2, sync1} <= 2'b00;
    else        {sync2, sync1} <= {sync1, src_sig};
// 使用 sync2 作为目标时钟域的输入
```

---

## 仿真命令（Icarus Verilog）

```bash
# 编译
iverilog -g2012 -s <tb_module> -o sim.out \
    path/to/dut.v path/to/tb.v

# 运行
vvp sim.out

# 查看波形（需要 GTKWave）
gtkwave wave.vcd
```

---

## 调试检查清单

**仿真行为异常时，按顺序检查：**

- [ ] 复位信号极性（高/低有效）是否匹配
- [ ] 时钟周期设置是否正确
- [ ] 激励时序是否在时钟边沿后一段时间改变（避免 setup 冲突）
- [ ] 所有输入是否有明确的初始值
- [ ] 跨时钟域信号是否正确打拍
- [ ] `$display` / `$monitor` 打印关键中间信号
- [ ] 缩小问题范围：注释掉部分逻辑，逐步定位
