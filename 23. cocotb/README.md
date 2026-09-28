# cocotb 入门环境

用 Python testbench 驱动 Verilog 计数器，检查复位、使能暂停、4 位回绕、运行中异步复位和复位后恢复。RTL 由 Icarus 执行，cocotb 负责激励和自动比对，GTKWave 用于查看波形。

初次学习请从 [cocotb 入门学习指南](cocotb_入门学习指南.md) 开始：包含完整示例、逐段讲解、仿真时序、动手练习和排错方法。

## Windows 快速运行

在 PowerShell 中执行（当前电脑已安装好环境）：

```powershell
Set-Location 'D:\Projects\FPGA\23. cocotb\counter'
.\run_windows.cmd
```

也可以直接调用独立环境的 Python，无需激活虚拟环境或更改 PowerShell 执行策略：

```powershell
& 'D:\Projects\FPGA\23. cocotb\.venv-win\Scripts\python.exe' 'D:\Projects\FPGA\23. cocotb\counter\run.py'
```

检查汇总 `TESTS=1 PASS=1 FAIL=0`。查看波形：

```powershell
gtkwave 'D:\Projects\FPGA\23. cocotb\counter\sim_build\win32\counter.fst'
```

当前 Windows 环境：cocotb 2.0.1、Python 3.12、Icarus 13.0；另安装 pytest 改善断言报错信息。Icarus 和 GTKWave 来自已有的 `C:\msys64\ucrt64\bin`。2026-09-20 已运行计数器测试通过，仿真时间 245 ns；没有做综合或上板验证。

## 文件与运行机制

| 文件 | 用途 |
| --- | --- |
| [counter/counter.v](counter/counter.v) | 可综合的 4 位计数器，低有效异步复位 |
| [counter/test_counter.py](counter/test_counter.py) | Python 激励、参考值计算和断言 |
| [counter/run.py](counter/run.py) | 调用 Icarus 编译并执行 cocotb |
| [counter/run_windows.cmd](counter/run_windows.cmd) | 使用 Windows 独立环境启动示例 |
| [counter/requirements.txt](counter/requirements.txt) | 固定 cocotb 版本 |

`run.py` 指定 DUT 为仿真顶层，不需要另写 Verilog TB。Windows 产物放在 `counter/sim_build/win32/`，WSL 产物放在 `counter/sim_build/linux/`；`win32` 是 Python 的平台标识，不表示正在使用 32 位 Python。构建产物、波形和虚拟环境均已忽略。

测试在下降沿驱动使能，在上升沿之后等待 `ReadOnly()` 再检查寄存器输出，避免与 RTL 的非阻塞赋值更新竞争。这里是教学用计数器；复位在仿真中选择远离采样沿释放，上板时仍需按时钟域处理复位释放。

## WSL 运行

原有 Linux 虚拟环境继续使用，在 WSL Ubuntu 中执行：

```bash
cd "/mnt/d/Projects/FPGA/23. cocotb/counter"
../.venv/bin/python run.py
```

Windows 的 `.venv-win` 和 WSL 的 `.venv` 不能混用。

## Windows 环境重建

前提：Windows Python 3.12、`iverilog` 和 `vvp` 已加入 PATH。以下命令在 PowerShell 中执行，适用于尚未创建环境的新副本：

```powershell
Set-Location 'D:\Projects\FPGA\23. cocotb'
python -m venv .venv-win
.\.venv-win\Scripts\python.exe -m pip install -r .\counter\requirements.txt pytest
.\counter\run_windows.cmd
```

如果报告缺少 cocotb，先确认是否使用 `.venv-win\Scripts\python.exe`；如果找不到 Icarus，使用 `Get-Command iverilog,vvp` 检查 PATH。cocotb 的测试能力仍受后端 simulator 的 HDL 支持范围限制。

## 参考

- [cocotb 2.0.1 安装说明](https://docs.cocotb.org/en/v2.0.1/install.html)
- [仿真器支持与波形配置](https://docs.cocotb.org/en/v2.0.1/simulator_support.html)
