# cnn_ram 学习笔记

## 1. 项目定位

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/AGENTS.md`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`


`cnn_ram` 是一个 **Cortex-M0 + CNN 加速器** 的软硬协同项目，包含两条主线：

- **Vivado 工程**：负责 SoC 与 CNN RTL
- **Keil 工程**：负责 Cortex-M0 固件

这个项目的核心不是“纯软件跑 CNN”，而是：

> 让 Cortex-M0 作为控制核心，通过总线把图像数据送入 FPGA 内部的 CNN 加速器，再输出分类结果。

---

## 2. 目录结构

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/AGENTS.md`


```text
cnn_ram/
├── Vivado/CM0_Proj/    # FPGA 工程
└── Keil/Keil_proj/     # Cortex-M0 固件工程
```

重点文件：

- `Vivado/.../new_rtl/CortexM0_SoC.v`：SoC 顶层
- `Vivado/.../new_rtl/cortexm0ds_logic.v`：Cortex-M0 核
- `Vivado/.../cnn_verilog/*.v`：CNN RTL
- `Vivado/.../sources_1/new/cnn_top.v`：CNN 顶层
- `Keil/Keil_proj/USER/main.c`：固件入口

---

## 3. 软件和硬件分别在哪

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/new/cnn_top.v`


### 软件

软件在：

- `Keil/Keil_proj/USER/main.c`

负责：

- `SystemInit()`
- `UartInit()`
- `GpioInit()`
- 向 CNN 地址空间写图像
- 读分类结果
- 通过 UART 打印结果

### 硬件

硬件在：

- `Vivado/.../new_rtl/CortexM0_SoC.v`
- `Vivado/.../cnn_verilog/`

其中：

- `CortexM0_SoC.v`：系统总装图
- `cnn_top.v`：CNN 数据通路顶层
- `conv1_layer / maxpool_relu / conv2_layer / fully_connected / comparator`：CNN 主链路

---

## 4. 系统整体架构

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_subsystem.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave.v`


### 4.1 SoC 视角

```text
Keil main.c
   ↓
Cortex-M0 CPU
   ↓ (AHB write/read)
AHB Bus Matrix
   ├─ FLASH / SRAM
   ├─ GPIO
   ├─ DMA
   ├─ AHB-to-APB
   │    └─ UART / Timer / WDT
   └─ AHB_CNN @ 0x60000000
            ↓
       cnn_top
         ├─ conv1_layer
         ├─ maxpool_relu
         ├─ conv2_layer
         ├─ fully_connected
         └─ comparator
```

### 4.2 数据流视角

```text
test_03_buf[784]
   ↓
main.c 往 0x60000000 连续写数据
   ↓
AHB_CNN 从设备接收输入
   ↓
cnn_top 做推理
   ↓
decision / valid_out
   ↓
结果寄存器
   ↓
Cortex-M0 读取结果
   ↓
UART 打印
```

---

## 5. `0x60000000` 的意义

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`


这个地址不是普通 RAM，而是 **CNN 外设的 memory-mapped 基地址**。

在软件里写：

```c
mem32_write(0x60000000, value);
```

本质是：

- Cortex-M0 发起 AHB 写传输
- Bus Matrix 根据地址译码
- 命中 CNN 对应的从设备
- CNN 接收到输入数据

所以：

> CNN 在系统里不是“函数”，而是一个 **内存映射外设 / 硬件加速器**。

---

## 6. CNN 是函数还是外设？

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave.v`


结论：

> **CNN 不是软件函数，而是挂在 AHB 上的硬件外设。**

证据：

- 软件不是调用 `cnn_run()`
- 软件是通过固定地址 `0x60000000` 读写 CNN
- 硬件里存在 `AHB_CNN` 包装和 `cnn_top`

---

## 7. CNN 内部计算链路

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/new/cnn_top.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/cnn_verilog/conv1_layer.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/cnn_verilog/maxpool_relu.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/cnn_verilog/conv2_layer.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/cnn_verilog/fully_connected.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/cnn_verilog/comparator.v`


从 RTL 结构看，CNN 主要流程为：

1. `conv1_layer`
2. `maxpool_relu`
3. `conv2_layer`
4. `fully_connected`
5. `comparator`

对应思路：

```text
卷积1 -> 池化/ReLU -> 卷积2 -> 全连接 -> 最终比较输出类别
```

其中：

- `conv*_buf`：生成滑窗 / 行缓冲
- `conv*_calc`：卷积计算
- `comparator`：在最终分类结果中选最大值

---

## 8. 结果回传问题与修正

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`


### 8.1 原始工程的问题

原始 RTL 中：

- `cnn_top` 的 `decision` 和 `valid_out_6`
- 在 `cmsdk_ahb_eg_slave.v` 中是悬空的

这意味着：

- 输入链路已打通
- CNN 内部能算出结果
- **但结果没有真正传回 Cortex-M0**

原始 `main.c` 也只是：

- 打印欢迎信息
- 往 `0x60000000` 写 784 个像素
- 然后死循环

并没有读取结果寄存器。

### 8.2 修改后的结果回读方案

补充了一个最小结果接口：

- `0x60000000`：输入寄存器
  - `bit[7:0]`：输入像素
  - `bit[8]`：输入有效
- `0x60000004`：结果寄存器
  - `bit[3:0]`：分类结果
  - `bit[8]`：结果有效

软件流程：

```c
mem32_write(CNN_DATA_REG, data | 0x100);

while (1) {
  read_data = mem32_read(CNN_RESULT_REG);
  if (read_data & 0x100) {
    DEBUG_P("CNN result = %d\r\n", read_data & 0xF);
    break;
  }
}
```

这样就形成了完整闭环：

```text
CPU写输入 -> CNN推理 -> CPU读结果 -> UART打印
```

---

## 9. Cortex-M0 在这个项目里的角色

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cortexm0ds_logic.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`


在本项目中，Cortex-M0 不是算力主角，而是：

> **控制核心 / AHB 主设备 / 固件执行核心**

它主要负责：

1. 执行 `main.c`
2. 初始化 UART / GPIO
3. 发起 AHB 读写
4. 向 CNN 喂数据
5. 读结果并打印
6. 处理中断（例如 UART RX）

可以理解为：

> 软件做控制，硬件做加速。

---

## 10. Cortex-M0 来源判断

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cortexm0ds_logic.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_subsystem.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave.v`


当前项目中的 Cortex-M0 核并不像普通“开源核移植”，更像是：

> **基于 ARM DesignStart / CMSDK 参考工程的集成与二次开发**

依据：

- `cortexm0ds_logic.v` 文件头写有 `Cortex-M0 DesignStart processor logic level`
- 大量 `cmsdk_*` 文件头写有 `ARM Limited` 和 `Cortex-M System Design Kit`
- 系统骨架明显是 CMSDK 风格

所以本项目可以理解为：

```text
ARM Cortex-M0 DesignStart/CMSDK 骨架
        +
自定义 CNN 加速器
        +
Keil 固件
```

---

## 11. 作者可能的开发流程（推测）

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/new/cnn_top.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/cnn_verilog/*.v`


较高概率流程：

1. 先拿 ARM DesignStart / CMSDK 参考 SoC 跑通基础平台
2. 先做 UART / GPIO / 固件启动联调
3. 在 PyTorch 里训练 MNIST CNN
4. 导出量化后的权重和 bias 到 txt
5. 编写/整理 CNN Verilog 模块并单独验证
6. 用 CMSDK 的 AHB example slave 把 CNN 挂到 SoC
7. 在地址空间分配 `0x60000000` 给 CNN
8. 在 `main.c` 里用静态 `28x28` 图像做输入测试
9. 原始状态大概率停在“输入链路打通”，结果回传未收尾

支撑证据：

- RTL 中存在大量 `$readmemh(...)`
- 路径出现 `pyTorch/mnist_cnn`
- 权重文件名如 `conv1_weight_1.txt`、`fc_bias.txt`
- 固件中存在 `test_03_buf[784]`

---

## 12. CMSDK 是什么

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_ahb_to_apb.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_subsystem.v`


CMSDK = **Cortex Microcontroller System Design Kit**

可以理解为：

> **围绕 Cortex-M 内核构建 SoC 的官方参考积木包**

它通常包含：

- AHB/APB 基础设施
- AHB-to-APB bridge
- UART / Timer / GPIO / WDT
- RAM / ROM 参考模块
- 示例 slave

它的意义不是教你怎么造 CPU，而是教你：

> **如何把 CPU、总线、存储器、外设组织成一个 SoC。**

---

## 13. CMSDK 的典型分层

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_ahb_to_apb.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_subsystem.v`


```text
Cortex-M Core
   ↓
AHB Interconnect / Bus Matrix
   ├─ SRAM / ROM
   ├─ AHB 外设
   ├─ 自定义加速器
   └─ AHB-to-APB Bridge
            ↓
         APB 外设
         ├─ UART
         ├─ Timer
         └─ WDT
```

对于学习者最关键的价值：

1. 理解 SoC 是一个系统，而不是零散模块
2. 理解 memory-mapped I/O
3. 学会软硬协同

---

## 14. 寄存器接口设计思路

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`
- `FPGA/17. apb/apb_slave.v`


未来做 CMSDK 外设时，最关键的是寄存器设计。

最常见的寄存器类型：

- `CTRL`：控制寄存器
- `STATUS`：状态寄存器
- `DATA_IN`：输入数据寄存器
- `RESULT`：结果寄存器
- `CFG`：配置寄存器

最经典的加速器接口模型：

```text
Base + 0x00 CTRL
Base + 0x04 STATUS
Base + 0x08 DATA_IN
Base + 0x0C RESULT
```

软件侧典型流程：

```c
write(DATA_IN, x);
write(CTRL, START);
while (!(read(STATUS) & DONE)) ;
result = read(RESULT);
```

本项目当前接口是它的一个极简版。

---

## 15. 围绕 `cnn_ram` 的面试关键点

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/new/cnn_top.v`


### 最基础的 3 个问题

1. 软件和硬件分别在哪？
2. CPU 为什么往 `0x60000000` 写数据？
3. CNN 在系统里是函数还是外设？

### 进一步常见问题

1. 这个项目的数据流是什么？
2. AHB/APB 在这里分别承担什么角色？
3. `valid_in / valid_out` 为什么重要？
4. `conv*_buf` 的作用是什么？
5. 为什么卷积/全连接输出位宽变大？
6. 软件和 RTL 接口怎么协同？
7. 为什么原始工程里 UART 没有真正打印分类结果？

---

## 16. 当前项目最值得补的知识点

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/study_notes.md（本笔记综合章节）`


### P0（优先级最高）

1. AHB/APB 基础
2. memory-mapped I/O
3. Cortex-M0 启动与中断
4. CNN 硬件流水线
5. `valid` 信号与时序同步
6. 定点数与位宽设计

### P1

7. line buffer / sliding window
8. 权重量化与 `$readmemh`
9. 软硬协同接口设计
10. 仿真验证与波形调试

### P2

11. 更规范的寄存器映射
12. 中断方式替代轮询
13. DMA 喂数
14. 更规范的结果回读协议

---

## 17. 实践路线建议

### 本节对应文件（检索入口）

- `FPGA/17. apb/apb_slave.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`


为了真正掌握 CMSDK/SoC 设计，建议按以下顺序练习：

### 第 1 阶段：小外设练手

1. APB LED 外设
2. APB 计数器外设
3. UART + 寄存器读写联调

### 第 2 阶段：AHB 外设练手

4. AHB 只读状态寄存器
5. AHB start/done/result 小加速器
6. AHB FIFO / 求和器外设

### 第 3 阶段：回到 `cnn_ram`

7. 重构 CNN 寄存器接口为：
   - `CTRL`
   - `STATUS`
   - `DATA_IN`
   - `RESULT`
8. 用更规范的软件驱动方式控制 CNN
9. 再考虑中断 / DMA / 多图像输入

---

## 18. 一句话总结

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/study_notes.md（本笔记综合章节）`


> `cnn_ram` 是一个基于 ARM Cortex-M0 DesignStart/CMSDK 骨架构建的小型 SoC 学习项目，核心在于理解 **Cortex-M0 + AHB/APB 总线 + memory-mapped CNN 外设 + 固件驱动** 的完整软硬协同链路。

---

## 19. APB 时序图逐拍讲解：一次写和一次读到底发生了什么

### 本节对应文件（检索入口）

- `FPGA/17. apb/apb_slave.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_uart.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_subsystem.v`


APB 的核心特点是：

> 一次访问通常分成 **Setup（准备阶段）** 和 **Access（正式访问阶段）** 两拍。

最关键的判断是：

```text
PSEL = 1, PENABLE = 0  -> Setup
PSEL = 1, PENABLE = 1  -> Access
```

在很多 APB 从设备设计里，真正的读写动作通常在：

```verilog
PSEL && PENABLE
```

发生。

### 19.1 APB 关键控制信号回顾

- `PADDR`：目标地址
- `PWRITE`：1 表示写，0 表示读
- `PWDATA`：写数据
- `PRDATA`：读数据
- `PSEL`：选中外设
- `PENABLE`：进入正式访问阶段
- `PREADY`：外设是否准备好完成访问
- `PSLVERR`：是否错误

---

### 19.2 一次 APB 写操作逐拍发生了什么

假设 CPU 想往某个外设寄存器写入：

```text
地址 = 0x4000_0000
数据 = 0x0000_0055
```

#### 第 0 拍：空闲态（IDLE）

总线空闲时通常可以理解为：

```text
PSEL    = 0
PENABLE = 0
```

这表示当前没有访问。

#### 第 1 拍：Setup 阶段

主设备把地址、方向、数据准备好：

```text
PADDR   = 0x4000_0000
PWRITE  = 1
PWDATA  = 0x0000_0055
PSEL    = 1
PENABLE = 0
```

这一拍的含义是：

> “我要访问你了，地址和数据已经摆好，但现在还没正式执行。”

这一拍外设通常先做地址译码，判断：

- 访问的是哪个寄存器
- 这是读还是写

#### 第 2 拍：Access 阶段

主设备保持地址和数据稳定，同时拉高 `PENABLE`：

```text
PADDR   = 0x4000_0000
PWRITE  = 1
PWDATA  = 0x0000_0055
PSEL    = 1
PENABLE = 1
```

如果从设备：

```text
PREADY = 1
```

那么这次写操作就在这一拍完成。

外设一般会在这时更新寄存器，例如：

```verilog
if (PSEL && PENABLE && PWRITE)
  reg0 <= PWDATA;
```

#### 第 3 拍：回到空闲或进入下一次访问

写完成后：

- 如果没有下一次访问，`PSEL` 拉低，回到空闲
- 如果还有下一次访问，可能直接进入下一个 Setup 阶段

---

### 19.3 APB 写操作时序图（简化理解版）

```text
时钟周期        T0           T1             T2             T3
状态           IDLE         SETUP          ACCESS         IDLE/Next

PSEL            0             1              1              0/1
PENABLE         0             0              1              0
PWRITE          x             1              1              x
PADDR           x           addr           addr             x
PWDATA          x           data           data             x
PREADY          x             x              1              x

结果：在 T2 这一拍完成写寄存器
```

---

### 19.4 一次 APB 读操作逐拍发生了什么

假设 CPU 想读取：

```text
地址 = 0x4000_0004
```

#### 第 0 拍：空闲态（IDLE）

```text
PSEL    = 0
PENABLE = 0
```

#### 第 1 拍：Setup 阶段

主设备给出读请求：

```text
PADDR   = 0x4000_0004
PWRITE  = 0
PSEL    = 1
PENABLE = 0
```

这一拍的含义是：

> “我要读这个地址，请准备数据。”

#### 第 2 拍：Access 阶段

主设备拉高 `PENABLE`：

```text
PADDR   = 0x4000_0004
PWRITE  = 0
PSEL    = 1
PENABLE = 1
```

从设备需要把读数据放到：

```text
PRDATA
```

例如：

```verilog
if (PSEL && !PWRITE)
  case (PADDR[3:2])
    2'b01: PRDATA = status_reg;
    default: PRDATA = 32'd0;
  endcase
```

如果同时：

```text
PREADY = 1
```

则读访问完成，主设备在这一拍取走 `PRDATA`。

#### 第 3 拍：回到空闲或下一次访问

访问完成后回到：

- 空闲态
- 或直接发起下一次访问

---

### 19.5 APB 读操作时序图（简化理解版）

```text
时钟周期        T0           T1             T2             T3
状态           IDLE         SETUP          ACCESS         IDLE/Next

PSEL            0             1              1              0/1
PENABLE         0             0              1              0
PWRITE          x             0              0              x
PADDR           x           addr           addr             x
PRDATA          x             x            rdata            x
PREADY          x             x              1              x

结果：在 T2 这一拍完成读数据
```

---

### 19.6 如果外设来不及响应，会发生什么？

这时就要用 `PREADY`。

如果外设还没准备好：

```text
PREADY = 0
```

那么 Access 阶段不会结束，总线会停在当前访问上，继续等待。

例如：

```text
时钟周期        T0      T1        T2        T3        T4
状态           IDLE    SETUP     ACCESS    ACCESS    ACCESS

PSEL            0       1         1         1         1
PENABLE         0       0         1         1         1
PREADY          x       x         0         0         1
```

这表示：

- T2：开始正式访问，但外设没准备好
- T3：继续等
- T4：`PREADY=1`，访问终于完成

所以：

> `PREADY` 的作用就是告诉主设备“再等等”或者“可以结束了”。

不过很多初学外设都会直接写成：

```verilog
assign PREADY = 1'b1;
assign PSLVERR = 1'b0;
```

也就是**无等待周期、无错误响应**的最简 APB 外设。

---

### 19.7 APB 从设备中最常见的读写判断方式

```verilog
wire apb_write = PSEL && PENABLE && PWRITE;
wire apb_read  = PSEL && PENABLE && !PWRITE;
```

这两个信号非常常见，因为它们正好对应：

- 正式写访问
- 正式读访问

然后你就可以写：

```verilog
always @(posedge PCLK or negedge PRESETn) begin
  if (!PRESETn)
    ctrl_reg <= 32'd0;
  else if (apb_write && (PADDR[3:2] == 2'b00))
    ctrl_reg <= PWDATA;
end

always @(*) begin
  if (apb_read) begin
    case (PADDR[3:2])
      2'b00: PRDATA = ctrl_reg;
      2'b01: PRDATA = status_reg;
      default: PRDATA = 32'd0;
    endcase
  end
  else begin
    PRDATA = 32'd0;
  end
end
```

---

### 19.8 用一句话记住 APB 时序

> **第一拍 Setup：把地址和方向摆好；第二拍 Access：拉高 `PENABLE`，正式完成读或写。**

---

### 19.9 初学 APB 最容易犯的错

1. 只判断 `PSEL`，不判断 `PENABLE`
2. 写寄存器时没有做地址译码
3. 读 `PRDATA` 时忘记给默认值
4. 不清楚 `PREADY` 的作用
5. 把 APB 当成“随时可写”，而没有区分 Setup/Access 两拍

在本仓库的学习约定里，也明确强调：

> **APB 的有效访问应理解为 `PSEL && PENABLE`。**

---

## 20. 为什么现在更应该先学 AHB

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`


在 `cnn_ram` 项目里：

- Cortex-M0 对外主接口是 **AHB**
- SRAM / FLASH / GPIO / DMA / CNN 都挂在 **AHB**
- APB 是从 AHB 再分出去的一条低速外设支路

所以从系统层次上说：

> **AHB 是主干，APB 是支线。**

如果 AHB 没理解清楚，就很难真正理解：

- CPU 为什么能访问 `0x60000000`
- Bus Matrix 为什么能把访问送到 CNN
- AHB-to-APB bridge 为什么存在

---

## 21. AHB 本体：最核心的概念

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`


AHB = **Advanced High-performance Bus**

可以先理解成：

> **片上系统里的主干总线，用来连接 CPU、存储器、高速外设和桥接模块。**

### 21.1 Master 和 Slave

#### Master
主动发起访问的一方。

在本项目里主要有：

- Cortex-M0
- DMA

#### Slave
被访问、负责响应的一方。

在本项目里主要有：

- SRAM / FLASH
- GPIO
- AHB-to-APB bridge
- CNN 外设

---

### 21.2 AHB 最关键的信号

- `HADDR`：访问地址
- `HWRITE`：1=写，0=读
- `HTRANS`：传输类型
- `HWDATA`：写数据
- `HRDATA`：读数据
- `HREADY`：本次传输是否可以推进 / 是否完成
- `HRESP`：响应结果
- `HSEL`：当前 slave 是否被选中

### 21.3 `HTRANS` 初学阶段重点

最常见四种类型：

- `00` = IDLE
- `01` = BUSY
- `10` = NONSEQ
- `11` = SEQ

初学阶段最重要的一句是：

> **`HTRANS[1] = 1` 基本就表示这是一笔有效访问。**

所以：

- `NONSEQ`
- `SEQ`

都属于有效传输。

---

## 22. AHB 为什么比 APB 更复杂

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`


AHB 比 APB 更复杂的根本原因是：

1. 它是系统主干总线
2. 它支持更高性能访问
3. 它采用了**流水化（pipeline）**思路

AHB 一次传输最核心的两阶段是：

- **地址阶段（Address Phase）**
- **数据阶段（Data Phase）**

一句话：

> **这一拍先说“我要访问谁”，下一拍再真正传写数据或取读数据。**

---

## 23. AHB 一次写操作和一次读操作的逐拍时序

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`


### 23.1 一次写操作（无等待周期）

假设 CPU 向 `0x60000000` 写入 `0x12345678`。

```text
时钟周期        T0                T1                T2
状态           IDLE          地址阶段A         数据阶段A

HSEL            0                 1                 1
HADDR           x           0x60000000       (下一笔地址或保持)
HTRANS          IDLE          NONSEQ           IDLE/SEQ
HWRITE          x                1                x
HSIZE           x              word              x
HWDATA          x                x           0x12345678
HRDATA          x                x                x
HREADY          1                1                1
HRESP         OKAY             OKAY             OKAY
```

#### 逐拍理解

##### T1：地址阶段
- `HADDR = 0x60000000`
- `HWRITE = 1`
- `HTRANS = NONSEQ`

含义：

> 我要发起一笔有效写传输，目标地址是 `0x60000000`

##### T2：数据阶段
- `HWDATA = 0x12345678`
- 如果 `HREADY = 1`

则写操作完成。

关键点：

> **地址在前一拍给，数据在后一拍给。**

---

### 23.2 一次读操作（无等待周期）

假设 CPU 读取 `0x20000000`。

```text
时钟周期        T0                T1                T2
状态           IDLE          地址阶段A         数据阶段A

HSEL            0                 1                 1
HADDR           x           0x20000000       (下一笔地址或保持)
HTRANS          IDLE          NONSEQ           IDLE/SEQ
HWRITE          x                0                x
HSIZE           x              word              x
HWDATA          x                x                x
HRDATA          x                x            读回的数据
HREADY          1                1                1
HRESP         OKAY             OKAY             OKAY
```

#### 逐拍理解

##### T1：地址阶段
- `HADDR = 0x20000000`
- `HWRITE = 0`
- `HTRANS = NONSEQ`

含义：

> 我要读这个地址，请对应的 slave 准备数据。

##### T2：数据阶段
- 被访问的 slave 给出 `HRDATA`
- 如果 `HREADY = 1`

则读访问完成。

关键点：

> **写数据来自 master，读数据来自 slave。**

---

### 23.3 AHB 为什么更高性能：因为可以流水重叠

AHB 支持：

- 当前传输 A 的数据阶段
- 和下一传输 B 的地址阶段

在同一拍重叠发生。

示意：

```text
时钟周期        T1                T2                T3
传输A         地址阶段A         数据阶段A
传输B                           地址阶段B         数据阶段B

HADDR      addrA             addrB
HWRITE       1                 1
HTRANS     NONSEQ            NONSEQ
HWDATA        x              dataA             dataB
HREADY        1                1                1
```

最关键的一句：

> **在 T2 这一拍，A 在传数据，B 在发地址。**

---

### 23.4 如果 `HREADY=0`，会发生什么

`HREADY` 表示：

> 当前这笔传输是否真的完成 / 总线能否继续推进。

如果 slave 来不及处理，就会把 `HREADY` 拉低。

#### 写操作等待示意

```text
时钟周期        T1                T2                T3                T4
状态          地址阶段A         数据阶段A         等待保持          完成

HADDR      0x60000000         保持               保持              下一笔
HWRITE         1               保持               保持               x
HTRANS      NONSEQ             保持               保持              下一笔
HWDATA          x          0x12345678       0x12345678            x
HREADY          1               0                 0                1
HRESP         OKAY            OKAY              OKAY             OKAY
```

含义：

- T2：访问开始，但 slave 没准备好
- T3：继续等待，地址和数据保持不变
- T4：`HREADY=1`，这次写 finally 完成

#### 读操作等待示意

```text
时钟周期        T1                T2                T3                T4
状态          地址阶段A         数据阶段A         等待保持          完成

HADDR      0x20000000         保持               保持              下一笔
HWRITE         0               保持               保持               x
HTRANS      NONSEQ             保持               保持              下一笔
HRDATA          x               无效/等待          无效/等待        有效数据
HREADY          1               0                 0                1
HRESP         OKAY            OKAY              OKAY             OKAY
```

所以：

> **`HREADY=0` 会把当前传输卡住，直到 slave 准备好。**

---

## 24. `cmsdk_ahb_eg_slave_interface.v` 的作用

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`


这个模块的作用可以概括为：

> **把 AHB-Lite 协议翻译成更简单的寄存器读写接口。**

也就是把总线侧复杂一点的信号：

- `haddrs`
- `htranss`
- `hsizes`
- `hwrites`
- `hreadys`
- `hwdatas`

翻译成内部更好用的：

- `addr`
- `read_en`
- `write_en`
- `byte_strobe`
- `wdata`

所以它本质上是一个：

> **AHB 协议适配器 / 翻译器**

---

## 25. 带着协议去读 `cmsdk_ahb_eg_slave_interface.v`

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`


### 25.1 有效访问入口：`trans_req`

文件中的关键判断：

```verilog
wire trans_req = hreadys & hsels & htranss[1];
```

含义：

- `hreadys = 1`：当前总线允许推进
- `hsels = 1`：这个 slave 被选中
- `htranss[1] = 1`：这是一笔有效传输（NONSEQ/SEQ）

所以：

> `trans_req` 表示当前这个 slave 收到了一笔真正有效的 AHB 请求。

---

### 25.2 读请求和写请求拆分

```verilog
wire ahb_read_req  = trans_req & (~hwrites);
wire ahb_write_req = trans_req &  hwrites;
```

含义很直接：

- `hwrites = 0` → 读请求
- `hwrites = 1` → 写请求

所以：

- `ahb_read_req`：有效读请求
- `ahb_write_req`：有效写请求

---

### 25.3 为什么要寄存地址：`addr_reg`

```verilog
always @(posedge hclk or negedge hresetn)
begin
  if (~hresetn)
    addr_reg <= {(ADDRWIDTH){1'b0}};
  else if (trans_req)
    addr_reg <= haddrs[ADDRWIDTH-1:0];
end
```

原因：

> **AHB 是流水化总线，地址阶段和数据阶段分离。**

如果不把地址先锁存下来，到了数据阶段，外面的地址可能已经变成下一笔访问的地址了。

所以 `addr_reg` 的作用就是：

> 把地址阶段的信息保存下来，供后面的数据阶段使用。

---

### 25.4 `read_en` 和 `write_en` 是怎么来的

文件中有：

```verilog
assign update_read_req = ahb_read_req | (read_en_reg & hreadys);
assign update_write_req = ahb_write_req | (write_en_reg & hreadys);
```

以及：

```verilog
read_en_reg  <= ahb_read_req;
write_en_reg <= ahb_write_req;
```

它们的本质就是：

> 把 AHB 协议时序，整理成后级寄存器逻辑更容易使用的 `read_en` / `write_en`。

也就是把“当前有没有一笔真正有效的读/写传输”变成一个简洁内部信号。

---

## 26. 从基础讲 `HSIZE`

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_ahb_to_apb.v`


AHB 数据总线通常是 32-bit，也就是 4 个字节：

```text
[31:24] [23:16] [15:8] [7:0]
 byte3   byte2   byte1  byte0
```

但 CPU 并不总是每次都访问 32 位，它可能访问：

- 1 字节（byte）
- 2 字节（halfword）
- 4 字节（word）

所以总线必须告诉 slave：

> **这次访问的数据宽度是多少？**

这就是 `HSIZE` 的作用。

### 26.1 `HSIZE` 常用编码

| `HSIZE` | 含义 |
|---|---|
| `3'b000` | byte（8-bit） |
| `3'b001` | halfword（16-bit） |
| `3'b010` | word（32-bit） |

---

## 27. 什么是 byte lane

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`


`byte lane` 可以理解成：

> **32 位数据总线里的每一个 8 位字节位置。**

对于 32-bit 数据线：

```text
HWDATA = [31:24] [23:16] [15:8] [7:0]
           lane3   lane2   lane1  lane0
```

所以：

- lane0 → `bit[7:0]`
- lane1 → `bit[15:8]`
- lane2 → `bit[23:16]`
- lane3 → `bit[31:24]`

地址最低两位 `HADDR[1:0]` 决定当前访问落在哪个 byte lane 上：

| `HADDR[1:0]` | 对应 byte lane |
|---|---|
| `00` | lane0 |
| `01` | lane1 |
| `10` | lane2 |
| `11` | lane3 |

---

## 28. 什么是 `byte_strobe`

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`


`byte_strobe` 的本质是：

> **告诉后级逻辑：32 位数据里的哪几个字节有效。**

它通常是 4 位，每一位对应一个 byte lane：

| `byte_strobe` 位 | 对应数据位 |
|---|---|
| `[0]` | `HWDATA[7:0]` |
| `[1]` | `HWDATA[15:8]` |
| `[2]` | `HWDATA[23:16]` |
| `[3]` | `HWDATA[31:24]` |

例如：

- `0001`：只有 lane0 有效
- `0100`：只有 lane2 有效
- `1111`：四个 lane 全有效

---

## 29. `HSIZE + HADDR[1:0]` 为什么会被翻译成 `byte_strobe`

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`


在 `cmsdk_ahb_eg_slave_interface.v` 中，组合逻辑为：

```verilog
if (hsizes == 3'b000) begin
  case(haddrs[1:0])
    2'b00: byte_strobe_nxt = 4'b0001;
    2'b01: byte_strobe_nxt = 4'b0010;
    2'b10: byte_strobe_nxt = 4'b0100;
    2'b11: byte_strobe_nxt = 4'b1000;
```

它的本质是：

> **根据访问宽度和地址对齐，计算“下一拍该写哪几个字节”。**

### 29.1 byte 访问

| `HSIZE` | `HADDR[1:0]` | `byte_strobe` | 有效字节 |
|---|---|---|---|
| byte | `00` | `0001` | `[7:0]` |
| byte | `01` | `0010` | `[15:8]` |
| byte | `10` | `0100` | `[23:16]` |
| byte | `11` | `1000` | `[31:24]` |

### 29.2 halfword 访问

| `HSIZE` | 对齐位置 | `byte_strobe` | 有效字节 |
|---|---|---|---|
| halfword | 低半字 | `0011` | `[15:0]` |
| halfword | 高半字 | `1100` | `[31:16]` |

### 29.3 word 访问

| `HSIZE` | `byte_strobe` | 有效字节 |
|---|---|---|
| word | `1111` | 全部有效 |

---

## 30. 为什么 `byte_strobe` 还要寄存

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`


文件里后面还有：

```verilog
always @(posedge hclk or negedge hresetn)
begin
  if (~hresetn)
    byte_strobe_reg <= {4{1'b0}};
  else if (update_read_req|update_write_req)
    byte_strobe_reg  <= byte_strobe_nxt;
end
```

原因和地址寄存一样：

> **AHB 地址阶段先给出 `HSIZE/HADDR`，但后级真正处理数据时往往已经到下一拍。**

所以必须把“哪几个字节有效”先保存下来。

后级寄存器模块最终只需要看：

```verilog
byte_strobe
```

就知道哪些字节允许写入。

---

## 31. 用一句话总结这几个概念

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`


- `HSIZE`：这次访问有多宽
- `HADDR[1:0]`：这些字节落在 32 位数据总线的哪个位置
- `byte lane`：32 位总线里的单个字节位置
- `byte_strobe`：哪几个 byte lane 真正有效

---

## 32. 当前阶段推荐的 AHB 学习顺序

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_ahb_to_apb.v`


### 第 1 阶段：先懂 AHB 本体

1. Master / Slave
2. 核心信号：`HADDR/HWRITE/HTRANS/HWDATA/HRDATA/HREADY/HRESP/HSEL`
3. 地址阶段 / 数据阶段
4. `HREADY` 的等待机制

### 第 2 阶段：看项目里的简化实现

1. `CortexM0_SoC.v`
2. `cmsdk_ahb_eg_slave_interface.v`
3. `cmsdk_ahb_eg_slave.v`
4. `cmsdk_ahb_eg_slave_reg.v`

目标：

> 真正理解 CPU 为什么写 `0x60000000` 就能驱动 CNN。

### 第 3 阶段：再看工程化主干

1. `AHB_BusMatrix_3x6_L1.v`
2. `cmsdk_ahb_ram.v`
3. `cmsdk_ahb_to_apb.v`

最后再回头看：

- `cmsdk_apb_subsystem.v`
- `cmsdk_apb_slave_mux.v`
- `cmsdk_apb_uart.v`

---

## 37. AHB 面试前收口三段（可直接背诵）

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/new/cnn_top.v`

> 目标：把“懂框架”收口成“能稳定输出”。建议每天练 3 轮。

### 37.1 口述闭环（2分钟）

> 这是一个 Cortex-M0 + AHB/APB + CNN 加速器的软硬协同 SoC。CPU 通过 AHB 主干访问外设，其中 CNN 是 memory-mapped 的 AHB 从设备。软件把 28x28 图像逐点写入 CNN 输入地址，Bus Matrix 按地址译码把访问路由到 CNN slave。AHB 接口层把总线信号翻译成内部寄存器读写控制，寄存器层把输入位段映射成 `cnn_data_in` 和 `cnn_data_valid`。CNN 数据通路完成卷积、池化、全连接和比较后，把 `decision` 和 `valid` 锁存到结果寄存器。CPU 轮询结果寄存器的 done 位，读出低位分类结果，再通过 UART 打印。整个链路形成“写入→计算→回读→可观测输出”的闭环。

### 37.2 信号闭环（1分钟）

> 一次写访问时，CPU 在地址阶段给出 `HADDR/HWRITE/HTRANS/HSIZE`，在数据阶段给出 `HWDATA`。Bus Matrix 根据 `HADDR` 译码并拉高对应 `HSEL`。slave 侧常用 `HREADY & HSEL & HTRANS[1]` 判断有效访问。若 slave 能立即完成，返回 `HREADYOUT=1`，`HRESP=OKAY`；若处理慢则拉低 ready 插入等待。读访问时流程类似，只是数据方向反过来：slave 在数据阶段给 `HRDATA`，通过总线回到 CPU。`NONSEQ` 表示新起点访问，`SEQ` 表示连续访问。

### 37.3 接口闭环（1分钟）

> 这个系统的寄存器接口是 memory-mapped 协议：输入寄存器用于写像素与输入有效位，结果寄存器用于读 done 和分类结果。软件流程是“写输入→轮询 done→读 result→串口打印”。硬件流程是“地址译码→寄存器更新→信号映射→CNN推理→结果锁存”。重点不是寄存器有多少个，而是位语义要清晰：哪些位软件写、哪些位硬件写、状态如何清除。这样驱动和硬件之间的契约才稳定。

### 37.4 使用建议（面试前）

1. 先按 2min+1min+1min 连续讲完一轮
2. 再随机抽一段单独讲，保证不依赖上下文
3. 被追问时优先回到“地址、信号、寄存器语义”三件事


这样会更顺。

---

## 33. 完整数据通路：main.c → CNN 推理 → 结果回读

### 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/new/cnn_top.v`


这一节把整个软硬协同链路彻底串起来。

### 33.1 先看整体架构分层

从软件到硬件，整个数据流可以分成 4 层：

```text
Layer 1: main.c (Keil 固件)
Layer 2: cmsdk_ahb_eg_slave_interface.v (AHB 协议翻译)
Layer 3: cmsdk_ahb_eg_slave_reg.v (寄存器读写)
Layer 4: cnn_top (CNN 推理)
```

---

### 33.2 从软件视角看：main.c 怎么写数据

在 `main.c` 里：

```c
mem32_write(CNN_DATA_REG, 0x100);
for(i=0;i<784; i++)
    mem32_write(CNN_DATA_REG, test_03_buf[i] | 0x100);
```

展开后等价于：

```c
*(volatile uint32_t *)0x60000000 = 0x100;
for(i=0;i<784; i++)
    *(volatile uint32_t *)0x60000000 = test_03_buf[i] | 0x100;
```

其中 `CNN_DATA_REG = 0x60000000`。

这意味着：

- 写地址 `0x60000000`
- 写数据 `test_03_buf[i]` + bit8=1

---

### 33.3 整体数据流图：从软件到 CNN

```text
================================================================================
Layer 1: main.c (Keil 固件)
================================================================================

mem32_write(0x60000000, pixel | 0x100)
        │
        │ CPU 发起 AHB 写传输
        ▼
================================================================================
Layer 2: Cortex-M0 AHB Master 接口
================================================================================

HADDR    = 0x60000000
HWRITE   = 1
HTRANS   = NONSEQ (有效传输)
HWDATA   = pixel | 0x100
        │
        │ AHB Bus Matrix 根据地址 0x60000000 译码
        │ 选中 HSEL_P5 (CNN slave)
        ▼
================================================================================
Layer 3: cmsdk_ahb_eg_slave.v (AHB slave 顶层)
================================================================================

接收 AHB 信号：
  HSEL, HADDR, HWRITE, HTRANS, HWDATA, HREADY
        │
        ▼
cmsdk_ahb_eg_slave_interface.v
        │
        │ 翻译成简单寄存器接口
        ▼
reg_addr         = 0x00
reg_write_en    = 1
reg_byte_strobe = 1111 (word 访问)
reg_wdata       = pixel | 0x100
        │
        ▼
================================================================================
Layer 4: cmsdk_ahb_eg_slave_reg.v (寄存器模块)
================================================================================

地址译码 wr_sel[0] = 1 (写 data0)
        │
        ▼
data0[7:0]   <= pixel          (写入像素)
data0[8]     <= 1              (valid 脉冲)
        │
        │ 下一拍自动清零 (else data0[8:0] <= 0)
        ▼
cnn_data_in    <= data0[7:0]    → CNN 输入像素
cnn_data_valid <= data0[8]      → CNN 输入有效脉冲
        │
        ▼
================================================================================
Layer 5: cnn_top (CNN 推理)
================================================================================

cnn_data_in 收到 784 个像素
cnn_data_valid 每拍一个有效脉冲
        │
        ▼
conv1_layer → maxpool_relu → conv2_layer → fully_connected → comparator
        │
        ▼
decision (4-bit 分类结果)
valid_out_6 (结果有效脉冲)
        │
        ▼
回写到 data1:
  data1[3:0] = decision
  data1[8]   = 1 (result valid)
```

---

### 33.4 结果回读通路：软件怎么读 CNN 结果

在 `main.c` 里：

```c
while(1) {
    read_data = mem32_read(CNN_RESULT_REG);
    if(read_data & 0x100) {
        DEBUG_P("CNN result = %d\r\n", read_data & 0xF);
        break;
    }
}
```

其中 `CNN_RESULT_REG = 0x60000004`。

展开后等价于：

```c
*(volatile uint32_t *)0x60000004;
```

---

### 33.5 结果回读数据流图

```text
================================================================================
Layer 1: main.c (Keil 固件)
================================================================================

mem32_read(0x60000004)
        │
        | CPU 发起 AHB 读传输
        ▼
================================================================================
Layer 2: Cortex-M0 AHB Master 接口
================================================================================

HADDR    = 0x60000004
HWRITE   = 0
HTRANS   = NONSEQ
        │
        | AHB Bus Matrix 译码，选中 CNN slave
        ▼
================================================================================
Layer 3: cmsdk_ahb_eg_slave.v
================================================================================

        │
        ▼
cmsdk_ahb_eg_slave_interface.v
        │
        | 翻译成简单寄存器读接口
        ▼
reg_addr     = 0x04 (偏移)
reg_read_en  = 1
        │
        ▼
================================================================================
Layer 4: cmsdk_ahb_eg_slave_reg.v
================================================================================

地址 0x04 对应 addr[3:2] = 01
        │
        ▼
读 data1 寄存器:
  data1 = {23'd0, 1'b1, 4'd0, cnn_decision}
        │
        │  bit[8]   = 1 (result valid)
        │  bit[3:0] = decision (0~9)
        ▼
rdata = data1
        │
        ▼
================================================================================
Layer 5: 回到 AHB 接口
================================================================================

HRDATA = rdata
        │
        | CPU 收到读数据
        ▼
================================================================================
Layer 6: main.c 解析结果
================================================================================

read_data = HRDATA
if (read_data & 0x100) {  // bit8 = 1 表示结果有效
    result = read_data & 0xF;  // 取低 4 位就是分类结果
    DEBUG_P("CNN result = %d\r\n", result);
}
```

---

### 33.6 关键寄存器映射表

| 地址 | 偏移 | 寄存器 | 含义 |
|---|---|---|---|
| `0x60000000` | +0x00 | `data0` | 输入寄存器：bit[7:0]=像素，bit[8]=valid |
| `0x60000004` | +0x04 | `data1` | 结果寄存器：bit[3:0]=decision，bit[8]=done |

---

### 33.7 数据流中每层的核心职责

| 层级 | 文件 | 核心职责 |
|---|---|---|
| L1 | `main.c` | 软件发起读写请求 |
| L2 | Cortex-M0 AHB | 把 CPU 指令转成 AHB 总线访问 |
| L3 | `cmsdk_ahb_eg_slave_interface` | 把 AHB 协议翻译成简单寄存器接口 |
| L4 | `cmsdk_ahb_eg_slave_reg` | 执行寄存器读写，连接 CNN 信号 |
| L5 | `cnn_top` | 执行 CNN 推理，产生结果 |

---

### 33.8 一句话总结整条链路

> **软件写像素到 0x60000000 → AHB 翻译成寄存器写 → 寄存器把数据转成 CNN 输入 → CNN 推理产生结果 → 结果写入寄存器 → 软件读 0x60000004 拿到分类结果。**

---

## 34. AHB 工程化主干：Bus Matrix / HSEL / HREADYOUT / HRDATA 回路

### 34.0 本节对应文件（检索入口）

- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/AHB_BusMatrix_3x6_L1.v`
- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_ahb_ram.v`
- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave.v`

> 建议先看 `CortexM0_SoC.v`，再看 BusMatrix 和各 slave。

### 34.1 这一层在系统里解决什么问题

前面我们已经理解了：

- AHB 协议本体
- AHB slave 接口翻译
- 寄存器层和 CNN 数据链路

这一节补的是“系统主干路由”——也就是：

> CPU 发出的 AHB 访问，如何被送到正确的 slave，并把响应送回 CPU。

### 34.2 关键连接信号（顶层可直接检索）

在 `CortexM0_SoC.v` 中可检索：

- `HSEL_P0 ~ HSEL_P5`
- `HREADYOUT_P0 ~ HREADYOUT_P5`
- `HRDATA_P0 ~ HRDATA_P5`

这些信号分别表示：

- `HSEL_Px`：第 x 个 slave 被选中（地址译码结果）
- `HREADYOUT_Px`：第 x 个 slave 当前是否 ready
- `HRDATA_Px`：第 x 个 slave 返回的读数据

### 34.3 Bus Matrix 的双向职责

Bus Matrix 不只是“前向路由”，还负责“反向路由”：

1. **前向**：把 master 的地址/控制/写数据送到命中的 slave
2. **反向**：把命中 slave 的 `HRDATA/HREADYOUT/HRESP` 返回给 master

所以它本质是 AHB 主干的“交通调度中心”，不是单纯地址译码器。

### 34.4 结合 CNN 通路看一笔真实访问

以软件写 `0x60000000` 为例：

1. Cortex-M0 发起有效 AHB 写传输
2. Bus Matrix 按地址译码，命中 CNN 对应端口（`HSEL_P5`）
3. 传输送入 `AHB_CNN`（`cmsdk_ahb_eg_slave`）
4. CNN slave 返回 ready/response，Bus Matrix 回送给 CPU

同理，CPU 读 `0x60000004` 时，数据会从 CNN slave 的 `HRDATA` 路径回到 CPU。

### 34.5 本节学习检查点

你需要能回答：

1. `HSEL` 是谁产生的，作用是什么？
2. `HREADYOUT` 和 master 看到的 `HREADY` 是什么关系？
3. 一次读访问时 `HRDATA` 为什么只来自“命中的 slave”？

---

## 35. AHB-to-APB Bridge：AHB 世界如何切到 APB 世界

### 35.0 本节对应文件（检索入口）

- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_ahb_to_apb.v`
- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_subsystem.v`
- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_slave_mux.v`
- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_uart.v`
- `Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`

> 检索关键词建议：`module cmsdk_ahb_to_apb`, `apb_select`, `PSEL`, `PENABLE`, `HREADYOUT`, `APBACTIVE`。

### 35.1 为什么必须有 bridge

在 SoC 中：

- Cortex-M0 主接口是 AHB
- UART/Timer/WDT 等低速外设更适合 APB

所以必须有一个协议转换层：

> AHB 侧看它是 slave，APB 侧看它是访问发起方（controller/master）。

### 35.2 在本项目里的连接关系

在 `CortexM0_SoC.v` 中可以看到：

- APB 子系统接在 AHB 某个从端口（`HSEL_P4`）
- APB 子系统对外导出 `PADDR/PWRITE/PWDATA/PENABLE`

因此 CPU 访问 UART 的真实路径是：

```text
Cortex-M0 -> AHB Bus Matrix -> AHB-to-APB bridge/APB subsystem -> UART
```

### 35.3 bridge 里的关键逻辑（`cmsdk_ahb_to_apb.v`）

可重点检索并理解：

1. `apb_select = HSEL & HTRANS[1] & HREADY`
   - 表示桥接模块收到一笔有效 AHB 访问

2. `PSEL` / `PENABLE` 生成
   - `PSEL` 表示 APB 访问选中
   - `PENABLE` 表示进入 APB access 阶段

3. `HREADYOUT` 状态机控制
   - bridge 会根据 APB 访问进度和 `PREADY/PSLVERR` 控制 AHB 侧 ready

4. `PSTRB` 生成
   - 根据 `HSIZE + HADDR[1:0]` 生成 APB 字节写使能

### 35.4 时序层面的核心理解

bridge 做了两类转换：

1. **协议转换**
   - AHB 信号组 → APB 信号组

2. **阶段转换**
   - AHB 流水访问 → APB Setup/Access 两拍访问

### 35.5 从“读 UART 寄存器”理解桥接

1. CPU 发 AHB 读请求，地址落在 APB 子系统地址段
2. Bus Matrix 把请求路由到 bridge
3. bridge 在 APB 侧发起一次读访问（`PSEL`→`PENABLE`）
4. APB slave 返回 `PRDATA/PREADY`
5. bridge 把 `PRDATA` 回送到 AHB `HRDATA`，并给出 `HREADYOUT/HRESP`

### 35.6 本节学习检查点

你需要能回答：

1. 为什么说 bridge 在 AHB 侧是 slave、在 APB 侧是 controller？
2. `PSEL` 与 `PENABLE` 在 bridge 中如何产生？
3. `PREADY/PSLVERR` 如何影响 AHB 侧 `HREADYOUT/HRESP`？

---

## 36. 新增章节快速检索索引（34~35）

| 章节 | 主题 | 建议先看文件 |
|---|---|---|
| 34 | AHB 主干路由：Bus Matrix/HSEL/HREADYOUT/HRDATA | `CortexM0_SoC.v` |
| 35 | AHB-to-APB 协议与时序转换 | `cmsdk_ahb_to_apb.v` |

可配合次级文件：

- `cmsdk_apb_subsystem.v`
- `cmsdk_apb_slave_mux.v`
- `cmsdk_apb_uart.v`

---

## 38. 启动到运行闭环：这个项目里“各自初始化”到底初始化了什么

### 38.0 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/CORE/startup_CMSDK_CM0.s`
- `FPGA/cnn_ram/Keil/Keil_proj/SYSTEM/system_CMSDK_CM0.c`
- `FPGA/cnn_ram/Keil/Keil_proj/SYSTEM/system.c`
- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_uart.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`

> 这一节不再零散看函数，而是把“上电后系统如何一步步走到 CNN 输出结果”完整串起来。

### 38.1 第 0 层：复位入口初始化

从启动文件可以直接看到：

```text
Reset_Handler
  -> 调用 SystemInit
  -> 跳转 __main
```

这意味着复位释放后，软件真正开始执行时，不是直接进 `main`，而是先经过：

1. `Reset_Handler`
2. `SystemInit()`
3. `__main`
4. `main()`

这里最重要的理解不是汇编细节，而是顺序：

> **先建立最基本的系统运行条件，再进入应用主流程。**

### 38.2 第 1 层：`SystemInit()` 初始化了什么

从 `system_CMSDK_CM0.c` 可以看到，这个工程里的 `SystemInit()` 很轻：

```c
void SystemInit (void)
{
  SystemCoreClock = XTAL;
}
```

也就是：

- 系统主时钟按板级/工程约定取 `XTAL = 50MHz`
- `SystemCoreClock` 被更新为这个频率

所以在这个项目里，`SystemInit()` 的角色不是“做很多外设配置”，而是：

> **把 CPU 对系统频率的认知先建立起来。**

这对后续串口波特率、延时、驱动初始化都有基础意义。

### 38.3 第 2 层：`UartInit()` 初始化了什么

`main.c` 里的 `UartInit()` 做了几件非常典型的事：

1. 打开发送功能 `UARTMode_Tx = ENABLE`
2. 打开接收功能 `UARTMode_Rx = ENABLE`
3. 关闭发送中断 `UARTInt_Tx = DISABLE`
4. 打开接收中断 `UARTInt_Rx = ENABLE`
5. 设置波特率 `UART_BaudRate = 115200`
6. 调用 `UART_Init(UART0, &UART_InitStruct)`
7. 使能 NVIC 中断 `NVIC_EnableIRQ(UARTRX0_IRQn)`

这里可以分成三层理解：

#### （1）功能层

- TX 使能：允许软件把字符发出去
- RX 使能：允许串口接收外部输入

#### （2）中断层

- 主流程里输出 CNN 结果并不依赖中断
- 但工程同时把 RX 中断打开了，因此串口还具备“接收回显”的能力

这可以从 `UARTRX_Handler()` 看出来：

```text
收到字符 -> 清中断 -> 再把字符发回去
```

也就是说这个工程里的 UART 既是：

- **调试输出口**（`DEBUG_P` 打印）
- 也是一个**基础交互口**（串口回显）

#### （3）系统角色层

对这个 CNN 项目来说，UART 初始化最关键的意义是：

> **它建立了“结果可观测通道”。**

如果 UART 不初始化成功，那么即使 CNN 已经算出结果，软件也很难把结果稳定地展示给外部。

### 38.4 第 3 层：`GpioInit()` 初始化了什么

`GpioInit()` 主要把若干 GPIO pin 配成普通输出模式：

- 配置 `GPIO_Pin_0 ~ GPIO_Pin_3`
- 模式设为 `GPIO_Mode_OUT`
- 中断关闭 `GPIO_Int_Disable`

这一层和 CNN 主链路关系不大，但它体现了一个很典型的嵌入式初始化思想：

> **先把外设工作模式明确下来，避免管脚处于默认但不可控的状态。**

如果把 UART 视为“输出结果的逻辑通道”，那么 GPIO 更像“基础板级 IO 资源预配置”。

### 38.5 第 4 层：`mem32_write/mem32_read` 初始化了什么

严格说，`mem32_write()` 和 `mem32_read()` 不是“初始化函数”，但它们完成了另一个更关键的准备：

> **把软件访问外设的方式固定成 memory-mapped 读写模型。**

从 `system.c` 可直接看到：

```c
void mem32_write(uint32_t sram_addr,uint32_t data)
{
    *(__IO uint32_t*)sram_addr = data;
}

uint32_t mem32_read(uint32_t sram_addr)
{
    return *(__IO uint32_t*)sram_addr;
}
```

这说明：

- 软件写某个地址，本质就是对某个 memory-mapped 外设寄存器发起总线写访问
- 软件读某个地址，本质就是对某个 memory-mapped 外设寄存器发起总线读访问

因此这一步不是“配置外设”，而是：

> **建立软件与总线/寄存器世界之间的统一接口模型。**

### 38.6 第 5 层：CNN 侧所谓“初始化”到底是什么

这个项目里的 CNN 没有单独的复杂配置寄存器组；它的“初始化”更准确地说是：

1. 软件先约定好基地址 `CNN_BASE_ADDR`
2. 再约定两个寄存器地址：
   - `CNN_DATA_REG = BASE + 0x0`
   - `CNN_RESULT_REG = BASE + 0x4`
3. 再约定两个寄存器的位语义：
   - 输入寄存器：`bit[7:0]` 是像素，`bit[8]` 是输入有效
   - 结果寄存器：`bit[3:0]` 是分类结果，`bit[8]` 是结果有效

所以这里的“CNN 初始化”本质不是设置卷积核，不是加载权重，而是：

> **把软硬件之间的寄存器契约先固定下来。**

一旦契约固定，软件就知道：

- 往哪里写
- 哪些位有效
- 什么时候读
- 读出来后如何解释

### 38.7 第 6 层：`main()` 里的初始化顺序为什么这样写

`main()` 的关键顺序是：

```text
SystemInit()
-> UartInit()
-> GpioInit()
-> 打印欢迎信息
-> 写 CNN 输入
-> 轮询结果寄存器
-> UART 打印分类结果
```

这个顺序非常合理，因为：

1. **先有系统时钟认知**，驱动层才能按既定频率工作
2. **先有 UART**，后面打印欢迎信息和推理结果才有意义
3. **再配 GPIO**，补齐基础 IO 状态
4. **最后再发起 CNN 任务**，此时系统已经可观测、可调试

这就是一个非常典型的嵌入式 bring-up 顺序：

> **先让系统能跑，再让系统能看见，再让系统去做任务。**

---

## 39. 从初始化到推理结果：把整个运行过程闭环讲一遍

### 39.0 本节对应文件（检索入口）

- `FPGA/cnn_ram/Keil/Keil_proj/CORE/startup_CMSDK_CM0.s`
- `FPGA/cnn_ram/Keil/Keil_proj/SYSTEM/system_CMSDK_CM0.c`
- `FPGA/cnn_ram/Keil/Keil_proj/SYSTEM/system.c`
- `FPGA/cnn_ram/Keil/Keil_proj/USER/main.c`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_ahb_to_apb.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`

### 39.1 用一句话先概括

> **系统先完成启动与外设初始化，再由 CPU 通过 memory-mapped AHB 访问把图像送入 CNN，最后通过结果寄存器回读并用 UART 打印分类结果。**

### 39.2 分 8 步理解整个闭环

#### 第 1 步：复位释放

- 处理器从 `Reset_Handler` 开始
- 先调用 `SystemInit()`
- 再进入后续 C 运行时入口和 `main()`

#### 第 2 步：建立最基础的软件运行环境

- `SystemCoreClock` 被设置为工程使用的时钟值
- 软件侧对系统频率有统一认知

#### 第 3 步：建立可观测输出通道

- `UartInit()` 配置 UART0
- 后续 `DEBUG_P()` 才能把文本发到串口调试助手

#### 第 4 步：建立基础 IO 状态

- `GpioInit()` 把若干 GPIO 管脚配置为输出
- 这一步虽然不是 CNN 的核心，但属于系统 bring-up 的固定动作

#### 第 5 步：软件发起 CNN 输入写入

- 软件调用 `mem32_write(CNN_DATA_REG, value)`
- CPU 发起 AHB 写访问
- Bus Matrix 按地址把这次写访问路由到 CNN slave

#### 第 6 步：AHB 接口层翻译访问

- `cmsdk_ahb_eg_slave_interface` 识别有效访问
- 把 AHB 协议翻译成内部更简单的寄存器写控制

这一层解决的是：

> **总线协议很复杂，但寄存器层只想知道“是不是写了哪个寄存器、写了什么数据”。**

#### 第 7 步：寄存器层驱动 CNN 计算

- 输入寄存器接收 `bit[7:0]` 像素和 `bit[8]` valid
- 这些信号送入 `cnn_top`
- CNN 完成推理后，把 `decision` 和 `valid` 回写到结果寄存器

#### 第 8 步：软件轮询结果并打印

- 软件不断读 `CNN_RESULT_REG`
- 一旦 `bit[8] = 1`，说明结果已经准备好
- 读取 `bit[3:0]` 得到分类号
- 通过 UART 打印出来

### 39.3 为什么这里采用“轮询”而不是“中断”

从现有代码看，CNN 结果回读采用的是最简单直接的方式：

```text
while(1) {
  read result reg;
  if (valid) break;
}
```

这样做的优点是：

1. 接口极简
2. 软件容易理解
3. 便于早期联调
4. 先证明结果链路闭环，再考虑复杂优化

因此它很适合学习阶段，也很适合面试讲解：

> **先用轮询把闭环打通，再谈中断/DMA 等优化。**

### 39.4 面试可直接背的闭环版本

> 这个系统上电后先从复位入口开始，调用 `SystemInit` 建立系统时钟认知，然后初始化 UART 和 GPIO，让系统先具备可观测性和基础 IO 状态。接下来主程序通过 memory-mapped 方式向 CNN 输入寄存器连续写入图像像素。CPU 发起的是 AHB 访问，Bus Matrix 根据地址把请求路由到 CNN 从设备，AHB 接口层再把总线协议翻译成内部寄存器读写控制。寄存器层把输入位段变成 CNN 的数据和 valid 信号，CNN 计算完成后把分类结果和结果有效位写回结果寄存器。软件持续轮询该寄存器，一旦 valid 位置位，就读出低位 decision，并通过 UART 打印，形成从启动、初始化、喂数、计算到输出的完整闭环。

---

## 40. APB / AHB / AHI 的辨析（详细版）

### 40.0 本节对应文件（检索入口）

- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/CortexM0_SoC.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_ahb_to_apb.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_subsystem.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/new_rtl/cmsdk_apb_uart.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_interface.v`
- `FPGA/cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/sources_1/imports/verilog/cmsdk_ahb_eg_slave_reg.v`

### 40.1 先给结论：三者不是同一层面的概念

- **AHB**：总线主干协议
- **APB**：挂在主干旁边的低复杂度外设总线协议
- **AHI**：本项目源码中没有这个标准命名；若当前语境提到它，更合理的理解是 **AHB interface（AHB 接口层）**，也就是把 AHB 事务翻译成内部寄存器读写控制的那一层

所以要先分清：

> **AHB/APB 是“总线协议层”的概念，而这里理解的 AHI 更像“协议适配/接口实现层”的概念。**

### 40.2 AHB 是什么

AHB = **Advanced High-performance Bus**。

它的定位是：

> **SoC 主干总线。**

它负责把 CPU、SRAM、Flash、DMA、自定义加速器等高带宽或主路径模块连接起来。

AHB 的几个核心特征：

1. 有主设备和从设备概念
2. 有地址阶段和数据阶段
3. 支持流水化
4. 有 `HREADY/HREADYOUT` 等等待机制
5. 一组信号比较完整：`HADDR/HWRITE/HTRANS/HSIZE/HWDATA/HRDATA/HRESP/HSEL`

在本项目里：

- Cortex-M0 对外主接口是 AHB
- CNN 是 AHB slave
- SRAM/Flash/bridge 都挂在 AHB 主干上

### 40.3 APB 是什么

APB = **Advanced Peripheral Bus**。

它的定位是：

> **低速外设总线。**

它通常服务 UART、Timer、WDT、GPIO 配置寄存器等低复杂度外设。

APB 的几个核心特征：

1. 结构简单
2. 没有 AHB 那样强调流水化
3. 访问通常分成 Setup / Access 两拍
4. 关键信号更少：`PADDR/PWRITE/PWDATA/PRDATA/PSEL/PENABLE/PREADY/PSLVERR`

在本项目里：

- UART 等外设位于 APB 子系统
- CPU 并不直接“说 APB”，而是先发 AHB
- 由 AHB-to-APB bridge 把请求转换到 APB 世界

### 40.4 当前语境下的 AHI 应该怎样理解

本仓库源码中检索不到 `AHI` 命名，因此这里不能把它当成一个已经被源码明确采用的标准模块名。

如果结合我们前面反复阅读的工程结构，当前语境里最合适的解释是：

> **AHI = AHB interface，也就是 AHB 从设备前端的接口翻译层。**

在这个项目里，它对应的不是一条独立总线，而是一类逻辑职责：

- 接收 AHB 侧信号
- 判断本次传输是否有效
- 处理地址对齐/字节使能/读写方向
- 向后级寄存器层输出更简单的控制信号

这正是 `cmsdk_ahb_eg_slave_interface` 这一层在做的事。

所以：

- **AHB**：公路本身
- **AHI**：收费站/匝道翻译层
- **寄存器层**：真正接收和执行命令的窗口

### 40.5 三者最核心的差别

| 维度 | AHB | APB | AHI（按本节定义） |
|---|---|---|---|
| 本质 | 总线协议 | 总线协议 | 接口/适配层 |
| 作用范围 | SoC 主干 | 低速外设支路 | AHB slave 前端 |
| 是否独立总线 | 是 | 是 | 否 |
| 主要任务 | 高性能传输与路由 | 简单寄存器访问 | 协议翻译 |
| 典型对象 | CPU、SRAM、CNN | UART、Timer、WDT | slave interface |
| 时序特点 | 地址/数据分离，可流水 | Setup/Access 两拍 | 跟随 AHB，向后级简化 |
| 复杂度 | 高 | 低 | 中等 |

### 40.6 结合本项目做最直观的区分

#### 情况 1：CPU 访问 CNN

路径是：

```text
CPU -> AHB Bus Matrix -> AHB CNN slave -> AHB interface -> reg -> cnn_top
```

这里：

- 走的是 **AHB**
- 前端翻译层可理解为 **AHI / AHB interface**
- 最终落到寄存器和 CNN 数据通路

#### 情况 2：CPU 访问 UART

路径是：

```text
CPU -> AHB Bus Matrix -> AHB-to-APB bridge -> APB UART
```

这里：

- 主干部分是 **AHB**
- 进入低速外设域后变成 **APB**
- 不需要专门把 UART 前端称为 AHI，因为它本来就是 APB 外设协议

### 40.7 为什么初学者容易把它们混在一起

因为从软件视角看，三者都长得像“访问某个地址”。

例如：

```c
mem32_write(addr, data);
```

对软件工程师来说，好像只是在“写地址”；但对硬件系统来说，背后可能是：

1. AHB 直连访问某个高性能外设
2. AHB 再桥接到 APB 外设
3. AHB 进入某个 slave 的接口层后，再落到内部寄存器

也就是说：

> **同一个软件动作，底下可能跨越“主干总线、桥接逻辑、接口翻译、寄存器层”四个层次。**

### 40.8 一句话强记版

- **AHB**：SoC 主干公路
- **APB**：低速外设支路
- **AHI**：如果在当前项目语境里使用，建议理解成 AHB 接口翻译层，不是一条独立总线

### 40.9 面试回答版

> AHB 和 APB 都是 AMBA 总线协议，但定位不同：AHB 是主干高性能总线，连接 CPU、存储器和自定义加速器；APB 是低复杂度外设总线，适合 UART、Timer 这类寄存器型外设。至于 AHI，在这个项目源码里没有一个独立的标准 AHI 总线命名，如果按当前讨论语境理解，更合适把它看成 AHB interface，也就是 AHB 从设备前端的协议翻译层。它不负责系统级路由，而是把 AHB 事务整理成寄存器层易于使用的读写控制。

---

## 41. 收官补充：本轮新增内容快速索引（38~40）

| 章节 | 主题 | 建议先看文件 |
|---|---|---|
| 38 | 启动链路与各自初始化 | `startup_CMSDK_CM0.s` |
| 39 | 初始化到结果输出的运行闭环 | `main.c` |
| 40 | APB / AHB / AHI 的辨析 | `CortexM0_SoC.v` |

建议配合阅读：

- `system_CMSDK_CM0.c`
- `system.c`
- `cmsdk_ahb_eg_slave_interface.v`
- `cmsdk_ahb_to_apb.v`
