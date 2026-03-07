---
name: digital-ic
description: Digital IC (ASIC) front-end design knowledge for engineers transitioning from FPGA. Covers UVM, STA, CDC, DFT, and low-power design concepts.
license: MIT
compatibility: opencode
metadata:
  domain: hardware
  target: digital-ic-frontend
---

# 数字IC前端设计 Skill

## 适用场景

- 解释 FPGA 与 ASIC 设计的差异
- 讲解 STA（静态时序分析）概念
- 解释 UVM 验证框架
- CDC（跨时钟域）分析
- 低功耗 / DFT 设计问题

---

## FPGA vs ASIC 关键差异

| 方面 | FPGA | ASIC |
|------|------|------|
| 验证 | 仿真 + 上板 | UVM + Formal + STA |
| 时序 | 工具自动处理 | 手写 SDC，人工收敛 |
| 功耗 | 非核心 | 核心优化目标 |
| DFT | 不需要 | 扫描链必须设计 |
| 迭代成本 | 低（重新烧录）| 极高（流片费用） |
| 代码质量 | 灵活 | 严格的综合友好写法 |

---

## 静态时序分析（STA）核心概念

### 时序路径四类

```
① 输入→寄存器：  IN_PORT → [组合逻辑] → FF_D
② 寄存器→寄存器：FF_Q → [组合逻辑] → FF_D   ← 最关键
③ 寄存器→输出：  FF_Q → [组合逻辑] → OUT_PORT
④ 输入→输出：    IN_PORT → [组合逻辑] → OUT_PORT
```

### 建立时间检查（Setup）

```
数据到达时间 = 发送FF时钟边沿 + 时钟网络延迟 + 组合逻辑延迟
数据需要时间 = 捕获FF时钟边沿 + 时钟网络延迟 - 建立时间

要求：数据到达时间 < 数据需要时间
裕量（Slack）= 需要时间 - 到达时间 > 0
```

### SDC 约束（Synopsys Design Constraints）

```tcl
# 定义时钟（替代 FPGA 的 XDC）
create_clock -period 10.0 -name sys_clk [get_ports clk]

# 输入延迟
set_input_delay -clock sys_clk -max 2.0 [get_ports {din[*]}]

# 输出延迟
set_output_delay -clock sys_clk -max 2.0 [get_ports {dout[*]}]

# 多周期路径
set_multicycle_path -setup 2 -from [get_cells u_div/...] -to [get_cells u_reg/...]

# 伪路径（不需要时序分析）
set_false_path -from [get_ports rst_n]
```

---

## 跨时钟域（CDC）处理

### 单 bit 信号

```verilog
// 2-flop 同步器（标准做法）
(* ASYNC_REG = "TRUE" *) reg sync1, sync2;
always @(posedge dst_clk or negedge rst_n)
    if (!rst_n) {sync2, sync1} <= 2'b0;
    else        {sync2, sync1} <= {sync1, src_sig};
```

### 多 bit 信号

```
方法1：格雷码 + 同步器（见 async_fifo 实现）
方法2：握手协议（req/ack）
方法3：异步 FIFO
方法4：使能信号控制下的寄存器传输
```

---

## 低功耗设计

| 技术 | 说明 | 节省 |
|------|------|------|
| 门控时钟 (CG) | 不翻转时关闭时钟 | 动态功耗 30-40% |
| 操作数隔离 | 避免无效数据传播翻转 | 组合逻辑功耗 |
| 多电压域 | 非关键路径降低电压 | 静态+动态功耗 |
| 功耗门控 (PG) | 关闭不用模块的电源 | 静态漏电功耗 |

```verilog
// 门控时钟（RTL 写法）
always @(posedge clk or negedge rst_n)
    if (!rst_n) data_r <= 'd0;
    else if (data_en)       // ← 增加使能条件，综合工具会推断 CG
        data_r <= data_in;
```

---

## UVM 验证框架（关键概念）

```
UVM 层次：
  uvm_test
    └── uvm_env
          ├── uvm_agent (write side)
          │     ├── uvm_sequencer
          │     ├── uvm_driver
          │     └── uvm_monitor
          ├── uvm_agent (read side)
          └── uvm_scoreboard
```

```systemverilog
// 基本 UVM 组件示例
class my_driver extends uvm_driver #(my_transaction);
    `uvm_component_utils(my_driver)

    virtual my_if vif;

    task run_phase(uvm_phase phase);
        forever begin
            my_transaction tr;
            seq_item_port.get_next_item(tr);
            // 驱动 DUT 接口
            @(posedge vif.clk);
            vif.din   <= tr.data;
            vif.valid <= 1'b1;
            seq_item_port.item_done();
        end
    endtask
endclass
```

---

## DFT（可测试性设计）基础

### 扫描链（Scan Chain）

```
正常模式：FF 正常工作
测试模式：所有 FF 串成移位寄存器 → 输入测试向量 → 捕获结果 → 移出比较

关键信号：
  scan_en = 1：测试模式，FF 使用 scan_in 输入
  scan_en = 0：正常模式，FF 使用正常 D 输入
```

### RTL 扫描友好写法

```verilog
// ✅ 推荐：工具可自动插入扫描
always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 1'b0;
    else        q <= d;

// ❌ 避免：异步置位/清零（扫描插入复杂）
always @(posedge clk or negedge rst_n or posedge set)
    if (set)       q <= 1'b1;
    else if (!rst_n) q <= 1'b0;
    else           q <= d;
```

---

## 面试高频题

| 问题 | 要点 |
|------|------|
| 建立时间违例怎么修？ | 减少组合逻辑深度、流水线、换路径 |
| 格雷码为什么用于 FIFO？ | 每次只变1位，CDC 时不会产生错误中间值 |
| 门控时钟有什么风险？ | 毛刺，需要在时钟低电平期间切换 EN |
| CDC 为什么打2拍？ | 第1拍消除亚稳态，第2拍输出稳定值 |
| DFT 覆盖率目标？ | 通常 > 99% 故障覆盖率 |
| 异步复位同步释放的好处？ | 复位及时响应，释放时避免亚稳态 |
