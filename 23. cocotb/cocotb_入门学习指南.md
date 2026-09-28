# cocotb 入门学习指南：从运行计数器到独立编写自动检查

这份教程面向会读基础 Verilog、懂时钟与寄存器，但尚未使用 cocotb 的学习者。Python 只要求认识变量、函数、循环和列表；遇到 `async`、`await` 时会单独解释。

学习目标是：给一个简单 RTL 模块，能写出激励、计算预期结果、自动发现错误，并根据日志与波形定位问题。主线使用本仓库已有的 4 位计数器，Windows 本机即可操作。

本文对应 **cocotb 2.0.1**，不是任意版本通用的 API 说明。环境与示例位于 `D:\Projects\FPGA\23. cocotb`；Windows 安装步骤见第 2 节，WSL 流程与目录说明见 [环境 README](README.md)。

## 1. 先知道自己在学技术栈的哪一层

一个 HDL 仿真通常包含三个部分：被测电路、测试环境、仿真器。

| 部分 | 本教程采用 | 负责什么 |
| --- | --- | --- |
| DUT：被测设计 | `counter.v` | 描述计数器硬件行为 |
| Testbench：测试环境 | Python + cocotb | 驱动输入、等待事件、检查输出 |
| Simulator：仿真器 | Icarus Verilog | 执行 RTL、处理事件和仿真时间 |
| 波形查看工具 | GTKWave | 查看已记录的信号变化 |

可以把工作过程画成：

```text
run.py ──编译、启动──> Icarus 仿真器
                           │
                  ┌────────┴────────┐
                  │                 │
             Verilog DUT <──信号──> cocotb Python 测试
                  │                 │
               波形文件         日志、断言、测试结果
                  │
               GTKWave
```

**你学的是如何用 Python 组织硬件验证。** RTL 仍由仿真器执行，Python 测试不会被综合成 FPGA 电路。

你以前用 `iverilog + Verilog TB + GTKWave`，现在相当于增加了 `cocotb + Python TB` 这条测试路径。自检、随机激励和参考模型在 SystemVerilog 中也能实现；cocotb 的实用价值是方便复用 Python 的数据处理与建模能力。

对 CNN 加速器，后续可以让 Python 生成输入、计算定点参考结果，再逐项对比 RTL 输出。但 cocotb 不会自动解决定点量化、流水线对齐、CDC 或时序收敛问题。

## 2. 环境准备：Windows 安装与库一览

### 2.1 Windows 本机安装

一次性前提，本机当前已经具备：

| 工具 | 本机来源 | 用途 |
| --- | --- | --- |
| Python 3.12 | python.org 安装包，已加入 PATH | 运行 cocotb 测试 |
| Icarus Verilog 13 | `C:\msys64\ucrt64\bin`（MSYS2） | 编译并执行 RTL，提供 `iverilog` 和 `vvp` |
| GTKWave | 同上 MSYS2 目录 | 查看 `.fst` 波形 |

换新机器时：Python 从 [python.org](https://www.python.org/downloads/) 安装并勾选 Add to PATH；Icarus 与 GTKWave 可继续用 MSYS2，在 MSYS2 终端执行：

```bash
pacman -S mingw-w64-ucrt-x86_64-iverilog mingw-w64-ucrt-x86_64-gtkwave
```

装完把 `C:\msys64\ucrt64\bin` 加入 Windows PATH。然后确认四个命令都能找到：

```powershell
Get-Command python, iverilog, vvp, gtkwave
```

创建虚拟环境并安装依赖，只需做一次，在 `23. cocotb` 目录执行：

```powershell
Set-Location 'D:\Projects\FPGA\23. cocotb'
python -m venv .venv-win
.\.venv-win\Scripts\python.exe -m pip install -r .\counter\requirements.txt pytest
```

`requirements.txt` 固定 `cocotb==2.0.1`，保证教程写法与库版本一致；`pytest` 用来改善断言失败时的报错信息。安装 cocotb 时会自动带上 `cocotb-tools`（Runner 所在的包），不用单独安装。

最后跑一次自带示例，验证环境可用：

```powershell
.\counter\run_windows.cmd
```

日志末尾出现 `TESTS=1 PASS=1 FAIL=0` 即安装成功。`TESTS=1` 指执行了一个 `@cocotb.test` 标记的测试，其内部有多次断言，不代表只检查了一次。需要看波形时：

```powershell
gtkwave 'D:\Projects\FPGA\23. cocotb\counter\sim_build\win32\counter.fst'
```

Windows 使用 `.venv-win`，WSL 使用 `.venv`，两者不能混用；WSL 流程见 [环境 README](README.md)。

### 2.2 本教程用到哪些库和函数

Python 侧的核心只有一个库 cocotb，其余是 Python 标准库：

| 导入 | 来自哪个包 | 用途 |
| --- | --- | --- |
| `import cocotb` | cocotb | 测试框架本体：`@cocotb.test` 注册测试；`dut` 对象读写 RTL 信号；`cocotb.start_soon()` 启动并发协程 |
| `from cocotb.clock import Clock` | cocotb | 生成周期时钟，`start()` 之后自动翻转 `dut.clk` |
| `from cocotb.triggers import ...` | cocotb | 各种「等到某事件发生」的触发器，是 `await` 的对象 |
| `from cocotb_tools.runner import get_runner` | cocotb-tools（随 cocotb 自动安装） | 在 Python 脚本里完成编译与启动，代替手敲 `iverilog` 命令 |

测试文件里出现的函数与触发器：

| 名称 | 用途 |
| --- | --- |
| `@cocotb.test(timeout_time=2, timeout_unit="us")` | 把 `async def` 函数注册为一个测试，并设置 2 μs 仿真时间上限 |
| `Clock(dut.clk, 10, unit="ns").start(start_high=False)` | 启动周期 10 ns（100 MHz）的时钟，从低电平开始 |
| `await RisingEdge(dut.clk)` | 暂停当前协程，等到时钟上升沿事件再继续 |
| `await FallingEdge(dut.clk)` | 等下降沿，本教程用它安排下一拍输入 |
| `await ReadOnly()` | 等当前仿真时刻的逻辑全部计算完再读输出，避免读到更新前的旧值 |
| `await Timer(1, unit="ns")` | 推进 1 ns 仿真时间，不是让电脑等待 |
| `dut.en_i.value = 1` | 驱动 DUT 输入信号 |
| `int(dut.count_o.value)` | 把输出逻辑值转换成 Python 整数再比较 |
| `runner.build()` / `runner.test()` | 编译 RTL / 启动仿真并加载 Python 测试 |

启动器 `run.py` 另外用了标准库 `pathlib`（拼路径）和 `sys`（按 `sys.platform` 区分 `win32`/`linux` 产物目录）；练习三会用到 `random.Random(seed)` 生成可复现的随机激励。

这些函数的具体写法和时序含义，在第 4、5 节结合代码展开。

## 3. 先写验证目标，再看代码

我们的设计只有一个 4 位无符号计数寄存器，规格如下：

| 信号 | 方向 | 意义 |
| --- | --- | --- |
| `clk` | 输入 | 上升沿更新寄存器 |
| `rst_n` | 输入 | 低有效异步复位，优先级最高 |
| `en_i` | 输入 | 为 1 时计数，为 0 时保持 |
| `count_o[3:0]` | 输出 | 取值范围 0～15 |

上升沿到来时，预期状态转移是：

```text
rst_n == 0：next_count = 0
rst_n == 1 且 en_i == 1：next_count = (count + 1) mod 16
rst_n == 1 且 en_i == 0：next_count = count
```

异步复位还有额外要求：`rst_n` 从 1 变为 0 时，不必等上升沿就应清零。

据此列出检查点，而不是随便输入几个数：

| 检查点 | 如何触发 | 应看到什么 |
| --- | --- | --- |
| 初始复位 | 开始时拉低 `rst_n` | 输出为 0 |
| 连续计数 | 连续使能 5 拍 | 1、2、3、4、5 |
| 暂停 | 关闭使能 3 拍 | 连续保持 5 |
| 回绕 | 再使能 13 拍 | 跨过 15→0，最后为 2 |
| 运行中异步复位 | 计数非零时在下降沿拉低复位 | 下次上升沿前已经为 0 |
| 复位优先级 | 保持复位且 `en_i=1` | 仍为 0 |
| 复位后恢复 | 释放复位且保持使能 | 下一上升沿变为 1 |

## 4. 三个文件组成一个完整示例

### 4.1 DUT：counter.v

文件：[counter/counter.v](counter/counter.v)。

```verilog
`timescale 1ns/1ps

module counter (
  input wire clk,
  input wire rst_n,
  input wire en_i,
  output reg [3:0] count_o
);
  // 4 位寄存器自然截断：15 再加 1 回到 0。
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      count_o <= 4'd0;
    else if (en_i)
      count_o <= count_o + 4'd1;
  end
endmodule
```

硬件上这是带异步清零和使能的 4 位寄存器及加法逻辑；使能也可能由反馈选择逻辑实现，取决于综合目标。时序过程里没有 `else` 表示寄存器保持，不会因此推导出锁存器。

### 4.2 测试：test_counter.py

文件：[counter/test_counter.py](counter/test_counter.py)。下面是完整测试，可以直接与本地文件对照。

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge, Timer


@cocotb.test(timeout_time=2, timeout_unit="us")
async def counter_basic(dut):
  dut.clk.value = 0
  dut.rst_n.value = 0
  dut.en_i.value = 0
  Clock(dut.clk, 10, unit="ns").start(start_high=False)

  # 上升沿之后等待 RTL 更新完成，再检查复位结果。
  await RisingEdge(dut.clk)
  await ReadOnly()
  assert int(dut.count_o.value) == 0, "复位后没有清零"

  # 在下降沿释放复位，避免和 DUT 的上升沿采样竞争。
  await FallingEdge(dut.clk)
  dut.rst_n.value = 1

  expected = 0
  # 先计数 5 拍，再暂停 3 拍，继续 13 拍跨过 15 -> 0。
  enables = [1] * 5 + [0] * 3 + [1] * 13
  for cycle, enable in enumerate(enables, start=1):
    await FallingEdge(dut.clk)
    dut.en_i.value = enable
    await RisingEdge(dut.clk)
    expected = (expected + enable) % 16
    await ReadOnly()
    actual = int(dut.count_o.value)
    assert actual == expected, (
      f"第 {cycle} 拍: en={enable}, 期望 {expected}, 实际 {actual}"
    )
    dut._log.info("cycle=%02d en=%d expected=%d actual=%d",
                  cycle, enable, expected, actual)

  # 当前计数非零，在两个上升沿之间拉低复位，验证异步清零。
  await FallingEdge(dut.clk)
  dut.rst_n.value = 0
  await Timer(1, unit="ns")
  await ReadOnly()
  assert int(dut.count_o.value) == 0, "异步复位未立即清零"

  # 复位保持有效时，即使 en=1，也必须保持 0。
  await RisingEdge(dut.clk)
  await ReadOnly()
  assert int(dut.count_o.value) == 0, "复位优先级错误"

  await FallingEdge(dut.clk)
  dut.rst_n.value = 1
  await RisingEdge(dut.clk)
  await ReadOnly()
  assert int(dut.count_o.value) == 1, "复位释放后未恢复计数"
```

### 4.3 启动器：run.py

文件：[counter/run.py](counter/run.py)。

```python
from pathlib import Path
import sys

from cocotb_tools.runner import get_runner


if __name__ == "__main__":
  project = Path(__file__).resolve().parent
  build = project / "sim_build" / sys.platform
  runner = get_runner("icarus")
  # 仿真顶层直接指定 DUT，不需要额外的 Verilog TB。
  runner.build(
    sources=[project / "counter.v"],
    hdl_toplevel="counter",
    build_dir=build,
    always=True,
    waves=True,
  )
  runner.test(
    hdl_toplevel="counter",
    test_module="test_counter",
    test_dir=project,
    results_xml=build / "results.xml",
    waves=True,
  )
```

这里只需先记住三项配置：

| 配置 | 本例的值 | 换模块时怎么改 |
| --- | --- | --- |
| `sources` | `counter.v` | 写入 DUT 及它依赖的 RTL 文件 |
| `hdl_toplevel` | `counter` | 填 Verilog 的模块名，不是文件名 |
| `test_module` | `test_counter` | 填 Python 测试模块名，不带 `.py` |

`runner.build()` 编译 RTL；`runner.test()` 启动仿真并加载 Python 测试。这里顶层是 DUT，时钟和输入由 cocotb 驱动，所以不用另写 Verilog TB。平时直接使用 Icarus 跑 Verilog TB 时，顶层仍应指定那个 TB。

Python Runner 的接口随版本可能调整，本教程固定使用 2.0.1 的写法。参见 [官方 Runner 文档](https://docs.cocotb.org/en/v2.0.1/runner.html)。

## 5. 逐步理解 Python 测试

### 5.1 dut 是进入电路的入口

`dut` 是 cocotb 传给测试的顶层对象，可以通过它访问 RTL 端口。

```python
# 片段：写 DUT 输入。
dut.en_i.value = 1

# 片段：把确定的二进制输出转换成 Python 整数。
actual = int(dut.count_o.value)
```

`dut.count_o` 是信号句柄，`.value` 是读取的逻辑值。初学时只驱动 DUT 输入，不给 `count_o` 这样的 DUT 输出赋值。

### 5.2 async / await 是怎样推进测试的

`async def` 定义一个可以暂停、恢复的协程。`await RisingEdge(dut.clk)` 表示：当前测试先暂停，等到下一次时钟上升沿再继续。

暂停的是这个协程，仿真器和其他已启动的任务仍能运行。它不是“让 Windows 睡一会儿”。

| 写法 | 本教程中的用途 |
| --- | --- |
| `await FallingEdge(dut.clk)` | 等下降沿，准备下一拍输入 |
| `await RisingEdge(dut.clk)` | 等 DUT 的上升沿事件 |
| `await ReadOnly()` | 等当前仿真时刻的逻辑计算结束，再读取输出 |
| `await Timer(1, unit="ns")` | 推进 1 ns 仿真时间 |

不要用 `time.sleep()` 代替仿真等待，也不要把 `asyncio.run()` 当成 cocotb 的启动器。比如没有任何 `await` 的无限循环会占住执行，仿真时间无法正常前进。

### 5.3 Clock 的 10 ns 是完整周期

```python
Clock(dut.clk, 10, unit="ns").start(start_high=False)
```

它启动一个周期 10 ns、频率 100 MHz 的时钟，并从低电平开始。cocotb 2.0 的 `Clock.start()` 自己启动时钟任务；不要照搬旧版本把它再次包进 `cocotb.start_soon()` 的例子。

对于你自己编写的其他协程，需要并发执行时仍可以使用 `cocotb.start_soon(your_coroutine())`。并发 Driver/Monitor 留到下一阶段再学，本例一个测试协程就足够。

### 5.4 Python 如何表达 4 位回绕

```python
expected = (expected + enable) % 16
```

Python 整数不会像 4 位寄存器那样自动截断，所以模型必须自己表达 0～15 的范围。

当 `enable=0` 时，预期值保持；当 `enable=1` 时加一；15 加一后取模得到 0。这个模型从输入和规格计算，不能直接把 DUT 的输出当作下一次的预期值，否则可能把错误一起带入模型。

```python
enables = [1] * 5 + [0] * 3 + [1] * 13
```

这里 `*` 重复列表，`+` 拼接列表，合计 21 拍。`enumerate(..., start=1)` 同时给出从 1 开始的拍编号和当拍的使能。

### 5.5 assert 把“看起来正确”变成机器检查

```python
assert actual == expected, (
  f"第 {cycle} 拍: en={enable}, 期望 {expected}, 实际 {actual}"
)
```

相等时继续，不相等时抛出异常，当前测试失败。报错带上拍数、输入、预期值和实际值，通常比只打印 `FAIL` 更容易定位。

`@cocotb.test(timeout_time=2, timeout_unit="us")` 注册一个测试，并给它设置 2 μs 的**仿真时间**上限。这能捕获时间仍在推进但预期事件迟迟不来的情况，不能代替操作系统级超时来打断一个阻塞的 Python 无限循环。

信号访问和测试入口可查 [Writing Testbenches](https://docs.cocotb.org/en/v2.0.1/writing_testbenches.html)；时钟与超时参数可查 [2.0.1 API Reference](https://docs.cocotb.org/en/v2.0.1/library_reference.html)。

## 6. 最关键的时序知识：上升沿到了，不代表输出已更新

### 6.1 同一个仿真时间点内也存在执行顺序

例如计数器在 25 ns 的上升沿需要把 0 更新为 1，可以按下面的教学简图理解：

```text
20 ns：下降沿，Python 把 en_i 设为 1
       输入保持稳定
25 ns：clk 从 0 变为 1
       RisingEdge 触发，Python 测试可以被唤醒
       RTL 响应上升沿，执行时序逻辑
       非阻塞赋值更新 count_o，相关组合逻辑继续计算
       ReadOnly 阶段，Python 检查最终的 count_o
30 ns：下一个下降沿，可以驱动下一拍输入
```

因此对于本例，读取寄存器更新后的值应使用：

```python
await RisingEdge(dut.clk)
await ReadOnly()
actual = int(dut.count_o.value)
```

不能依赖只等待 `RisingEdge` 后立即读到新值。`ReadOnly()` 不增加半拍延迟，而是等待当前仿真时间点内的计算完成。不同后端的细节有差异，这一写法比依赖碰巧的调度顺序更稳妥。参见 [官方 Timing Model](https://docs.cocotb.org/en/v2.0.1/timing_model.html)。

### 6.2 为什么在下降沿设置输入

这个 DUT 在上升沿采样。提前半个周期驱动输入，可以避免测试与 DUT 在同一个采样沿修改、读取输入所引起的竞争。

这是本例的测试策略，不是所有协议的通用规则。后续写接口 Driver 时，要按照接口的采样时序安排驱动与观察。

尤其注意：检查上升沿更新后的寄存器输出，与记录“刚刚那个上升沿接受了什么事务”是不同需求。如果 `ready` 在上升沿后改变，只看 `ReadOnly` 阶段的新 `ready` 可能误判刚刚的握手；Monitor 必须按照协议保存采样沿处的握手条件。

### 6.3 ReadOnly 阶段不能继续写信号

下面是错误片段：

```python
await ReadOnly()
dut.en_i.value = 0  # 错误：当前处于只读阶段。
```

本例采用的正确顺序是：

```python
await ReadOnly()
actual = int(dut.count_o.value)
await FallingEdge(dut.clk)
dut.en_i.value = 0
```

不要在同一时刻连续等待两次 `ReadOnly()`，也不要用 `Timer(0)` 作为“等信号稳定”的替代。

### 6.4 异步复位为什么要在上升沿之前检查

若只在上升沿之后检查清零，即使你误把 RTL 改成同步复位，也可能通过。

本例在下降沿拉低 `rst_n`，过 1 ns 就检查：当前时钟周期为 10 ns，下一个上升沿还要等 5 ns。因此这个断言能够检查“没有新上升沿也清零”这一要求。

这里的 1 ns 是为了安排一个明确的中间观察点，并非认为寄存器有 1 ns 的物理复位延迟。RTL 功能仿真也不能验证真实触发器的 recovery/removal、亚稳态或复位释放的 CDC 风险。

## 7. 动手练习：按顺序完成四次实验

以下是留给你的练习，本文没有预先修改 DUT 或测试。每次只改一个地方，运行后观察，再手动撤销该次修改。不要回退整个目录，以免丢失自己的其他学习内容。

### 练习一：先预测，再运行

运行前写出 21 拍的计数结果，然后与日志核对。

检查答案：

```text
第 1～5 拍：  1 2 3 4 5
第 6～8 拍：  5 5 5
第 9～21 拍： 6 7 8 9 10 11 12 13 14 15 0 1 2
```

进一步观察波形：释放初始复位后，循环驱动第一拍之前有一个 `en_i=0` 的上升沿，因此计数不会提前增加。`cycle=1` 是测试循环的编号，不是从 0 ns 开始的第一个时钟周期。

**完成标准：** 能解释暂停阶段为什么还要继续逐拍检查，而不是跳过。

### 练习二：故意制造错误，验证断言是否有效

在 `counter.v` 中临时把 `+ 4'd1` 改成 `+ 4'd2`，重新运行。

预期：循环第 1 拍就应失败，因为预期为 1、实际为 2。确认错误后恢复原来的 `+ 4'd1`，再运行，应恢复通过。

进一步实验：临时把敏感列表中的 `or negedge rst_n` 去掉，使复位变成同步复位。预期最初的复位检查仍可能通过，但运行中的“异步复位未立即清零”断言应失败。完成后恢复敏感列表。

这些是**预期实验结果**，不是本文已执行的故障注入记录。

**完成标准：** 知道一个测试能运行通过，还不足以证明它有发现错误的能力。

### 练习三：加入可复现的随机使能

保留原来 21 拍的定向序列，再增加随机激励。这样正常计数、暂停和回绕仍然确定会被覆盖。

在 `test_counter.py` 顶部增加：

```python
import random
```

把 `enables = ...` 那一行替换为以下片段，其余循环保持原样：

```python
  seed = 2026
  rng = random.Random(seed)
  dut._log.info("随机使能 seed=%d", seed)
  enables = [1] * 5 + [0] * 3 + [1] * 13
  enables += [rng.randrange(2) for _ in range(100)]
  # 保证后面的异步复位检查前计数非零，且 en_i 最终为 1。
  enables += [1] * (1 if sum(enables) % 16 != 15 else 2)
```

为什么最后再加一两拍？原测试后半段依赖“复位前计数非零”和“使能为 1”。随机序列可能破坏这些前提，所以扩展测试时也必须维护已有检查的条件。

固定种子在相同环境下便于重现同一组激励。先确认种子 2026 通过，再改成 2027、2028；失败时记录种子和第一处不匹配。

这次增加后总仿真时间仍小于 2 μs。若改成上千拍，需同步调大测试超时，而不是误把超时报错认作 DUT 错误。

**完成标准：** 能说明定向测试负责哪些确定边界，随机测试补充哪些输入组合。随机运行很多拍不等于已经验证所有情况。

### 练习四：脱离示例写一个测试

先读懂现有文件，再备份自己的练习版本，然后尝试不照抄代码实现：

1. 复位后关闭使能，检查连续 8 拍保持为 0。
2. 连续计数 32 拍，检查每一拍并经历两次回绕。
3. 在计数非零时拉低复位，检查异步清零。
4. 释放复位后，交替开关使能 20 拍，每拍与模型比较。

允许查 API 名称，但应自己安排驱动、采样和参考值更新的顺序。如果沿用后半段“下一拍为 1”的断言，要保证恢复时确实使能。

**完成标准：** 不依赖肉眼扫描全部波形，测试能够自动给出结果；故意改坏加法或使能逻辑后能够报错。

## 8. 失败时按什么顺序检查

先找到日志中的**第一处异常或第一次断言失败**。最后一行的总失败信息通常只是结果。

| 现象 | 优先检查 | 处理方式 |
| --- | --- | --- |
| `No module named cocotb` | 是否用了系统 Python | 用 `run_windows.cmd` 或明确指定 `.venv-win` 的 Python |
| 找不到 `iverilog` / `vvp` | PATH 和工具安装 | 在 PowerShell 执行 `Get-Command iverilog,vvp` |
| 找不到测试模块 | `test_module` 和目录 | 应为 `test_counter`，不带 `.py`；检查 `test_dir` |
| 找不到某个 DUT 信号 | 名称与顶层 | 对照 RTL 端口名和 `hdl_toplevel` |
| 实际值像是晚了一拍 | 采样阶段或模型拍数 | 检查 `RisingEdge` 后是否等了 `ReadOnly`，再检查流水线延迟 |
| 在只读阶段写信号报错 | 上一次等待是什么 | 先进入下一次下降沿等可写时刻 |
| `int(...)` 无法转换 | 信号含 X/Z | 检查复位、未驱动输入、多驱动和初始化 |
| 超时报错 | 时钟、等待条件、测试长度 | 检查是否有时钟、条件是否可达、超时是否合理 |
| 打开波形却没有新结果 | 平台路径或编译失败 | 区分 `win32` 与 `linux`，检查文件更新时间 |

遇到 X/Z，先保留逻辑值查看：

```python
# 诊断片段：放在读取输出的位置，先看值，再尝试转换。
dut._log.info("count_o 原始逻辑值=%s", dut.count_o.value)
```

不要为了让测试通过就把未知位统一当成 0，这可能掩盖没有正确复位的电路。

查看失败波形时，优先加入失败信号及它的时钟、复位和控制信号，跳转到报错时间附近。先问输入是否按预期到达，再问 DUT 是否做错；Testbench 自己也可能有 bug。

## 9. 从计数器走向实际模块

### 9.1 下一个练习选同步 FIFO

计数器只有一个整数状态；FIFO 需要记住多笔数据，是学习参考模型和 Scoreboard 的合适下一步。

Scoreboard 是保存预期结果并与实际结果比较的检查组件。Python 中可用 `collections.deque` 保存预期队列：被 DUT 接受的写操作才入队，被 DUT 接受的读操作才出队并核对。

动手前必须确定：读数据是组合输出还是延迟一拍、满时同时读写是否允许写入、空时是否支持旁路。这些规格会改变模型，不能只套 `deque` 模板。

同步 FIFO 至少检查空、满、回绕、连续读写、同时读写、非法请求的约定行为和复位清空。异步 FIFO 再增加独立时钟、频率比例、相位和跨域标志延迟，留到同步 FIFO 掌握之后。

### 9.2 再选 APB 或 valid/ready 接口

这时把测试拆成三个职责会更清楚：

| 组件 | 职责 |
| --- | --- |
| Driver | 按协议时序把一个读写请求变成引脚激励 |
| Monitor | 观察接口实际接受的事务 |
| Scoreboard | 按规格预测结果，并与实际事务比较 |

例如 APB 传输完成应识别 `PSEL && PENABLE && PREADY`；valid/ready 接口要在规定采样沿两者同时有效才算接受。不能“每发一个请求就更新模型”，因为等待或背压时，请求可能尚未被接受。

单个小模块不必一开始就写复杂框架。等重复代码真的出现，再提取复位函数、事务函数和检查组件。

### 9.3 最后结合自己的 CNN 模块

先选 MAC、量化或单层卷积这样边界清晰的模块：Python 生成数据，定点模型计算预期值，cocotb 发送输入并收集输出。

这里最容易错的往往不是乘加公式，而是有符号解释、累加位宽、右移舍入、饱和或截断、张量布局和输出延迟。浮点 NumPy 结果不能直接作为位精确的定点硬件答案。

## 10. 学到什么程度算够用

| 阶段 | 可以用什么来证明 |
| --- | --- |
| 入门 | 独立运行和修改本例，解释 DUT、仿真器、Testbench 的分工 |
| 面试可讲 | 独立写计数器或 FIFO 自检，解释采样竞争、参考模型、边界测试与种子复现 |
| 小模块工程可用 | 有明确规格、自动检查、适用边界覆盖、超时、可复现失败和重复运行方式 |

这里“覆盖”首先指检查点是否被执行并检查，不能从 `PASS` 推导出完整的代码覆盖率或功能覆盖率。`PASS` 只说明本次执行路径上的检查没有发现失败。

建议按四次学习安排推进，时长按自己的掌握情况调整：

1. 第一次：完成第 1～4 节，跑通并看懂波形。
2. 第二次：读第 5～6 节，能解释每个等待点。
3. 第三次：完成第 7 节，体验测试如何发现错误。
4. 第四次：独立做一个同步 FIFO 自检，再决定是否迁移到自己的项目。

学完后自测：

- [ ] 我能解释为什么 cocotb 仍然需要 Icarus、Verilator 或其他仿真器。
- [ ] 我能区分仿真时间与电脑实际运行时间。
- [ ] 我知道本例为什么要下降沿驱动、上升沿后等待 `ReadOnly` 再检查。
- [ ] 我能从规格计算预期值，处理位宽和回绕。
- [ ] 我能验证使能保持、边界和异步复位，而不只是连续计数。
- [ ] 我能故意引入错误，确认测试会失败，并恢复正常版本。
- [ ] 我能解释为什么随机测试通过不等于验证完成。

## 11. 参考资料与验证范围

优先结合本地示例读以下官方资料，不必第一次就通读 API Reference：

- [Writing Testbenches](https://docs.cocotb.org/en/v2.0.1/writing_testbenches.html)：测试入口、读写信号和基本用法。
- [Timing Model](https://docs.cocotb.org/en/v2.0.1/timing_model.html)：事件与采样阶段。
- [Python Runner](https://docs.cocotb.org/en/v2.0.1/runner.html)：编译和启动测试。
- [API Reference](https://docs.cocotb.org/en/v2.0.1/library_reference.html)：查询 Clock、Trigger、超时等具体接口。
- [本地环境说明](README.md)：Windows/WSL 启动及环境重建。

本教程基于已有的计数器示例编写。原始计数器测试已在 Windows 和 WSL 运行通过；故障注入、随机扩展和后续 FIFO/APB/CNN 项目属于学习练习，没有据此宣称已经完成验证。RTL 仿真不替代综合、STA、CDC 检查或上板验证。
