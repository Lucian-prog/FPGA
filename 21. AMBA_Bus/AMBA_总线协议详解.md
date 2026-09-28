# AMBA 总线协议详解：从 APB 到 AHB 再到 AXI 的演进逻辑

> **学习目标**：读完这篇，你要能做到——
> ① 一句话说清 APB / AHB / AXI 各自解决什么问题、为什么同一颗 SoC 里三者共存；
> ② 白板画出三种协议的逐拍时序，写出一个最小从机；
> ③ 面试被追问「HREADY 和 HREADYOUT 什么区别」「AXI 握手为什么会死锁」「outstanding 怎么实现」时不卡壳。
>
> **配套代码**（本目录，`.\scripts\run_all.ps1` 一键仿真）：
> `rtl/ahb_lite_slave.v` · `rtl/axi_lite_slave.v` · `sim/*_tb.v`
>
> **仓库内引用资产**：
> `17. apb/apb_slave.v`（你写的 APB3 从机）· `cnn_ram/`（Cortex-M0 + AHB-Lite 真实 SoC）

---

## 一、先说结论

先把整篇的灵魂放这里，后面全是这句话的展开：

> **总线协议的演进史，就是「怎么让数据搬得更快」的历史。APB 用两拍搬一笔，图的是省电和简单；AHB 给总线装上流水线，一拍完成一笔；AXI 干脆把地址、数据、响应拆成五条独立通道，让它们互不等待地并行跑。**

演进逻辑一图流：

```
   外设寄存器访问            高性能主存访问           高频/高带宽 SoC 主干
   要简单、要省电            要流水线、要多主          要并行、要乱序、要打拍
 ┌───────────────┐       ┌───────────────┐       ┌───────────────┐
 │     APB       │       │      AHB      │       │      AXI      │
 │ 2 拍一笔，无流水│ ────▶ │ 1 拍一笔，流水 │ ────▶ │ 5 通道独立握手 │
 │ 单主，无仲裁   │       │ 多主，有仲裁   │       │ outstanding   │
 └───────────────┘       └───────────────┘       └───────────────┘
  UART/GPIO/Timer        CPU↔SRAM/DMA            DDR/GPU/NIC/加速器
  的配置寄存器           的骨干                   的主干（ZYNQ PS 就是）
```

三层总览表（先混个脸熟，细节后面逐层拆）：

| 维度 | APB | AHB(AHB-Lite) | AXI(AXI4) |
|------|-----|---------------|-----------|
| 一笔传输耗时 | 固定 ≥2 拍 | 零等待时 1 拍/笔 | 握手流水，可多笔并行 |
| 流水线 | 无 | 地址/数据两相位重叠 | 五通道各自独立流水 |
| 多主 | 单主 | 多主+仲裁器 | 天然多主（各发各的） |
| 乱序/并行 | 无 | 无 | outstanding + 乱序 |
| 典型时钟 | 最慢（几~几十 MHz） | 中 | 最高 |
| 典型带宽 | 低（寄存器配置够用） | 中 | 高 |
| 从机实现难度 | ★ | ★★ | ★★★ |
| 在 SoC 的位置 | 最外圈外设域 | 中间高速域 | 主干 |

---

## 二、AMBA 家族全景

### 2.1 AMBA 是什么

AMBA（Advanced Microcontroller Bus Architecture），ARM 1996 年推出的片上总线规范。

注意它的身份：**它是一份「接口协议文档」，不是 IP**。ARM 只定义信号名、时序规则、谁在什么时候拉高谁；你按文档写 RTL，就是「符合 AMBA 协议」的 master 或 slave。各家的总线 IP（包括你 cnn_ram 里 ARM 给的 cmsdk 例程、Xilinx 的 AXI Interconnect）都实现这套协议，所以能互相对接。

规范文档编号值得认识（面试提到会加分）：

| 协议 | 规范编号 | 备注 |
|------|---------|------|
| APB | IHI 0024 | APB2→3→4→5 演进 |
| AHB / AHB-Lite / AHB5 | IHI 0033 | AHB-Lite 是单主简化版 |
| AXI (AXI3/4/5) | IHI 0022 | ACE/CHI 是另外的规范 |

### 2.2 版本演进速查

```
APB:  APB2(无等待机制) → APB3(+PREADY/PSLVERR) → APB4(+PSTRB/PPROT) → APB5(+PWAKEUP)
AHB:  AHB(多主,SPLIT/RETRY) → AHB-Lite(单主链,最常用) → AHB5(+ exclu/原子操作,跟ACE搭)
AXI:  AXI3 → AXI4(burst 256,删WID,±Lite/Stream) → AXI5(+比AXI4小的增量)
      AXI 的扩展族: AXI4-Lite(寄存器配置) / AXI4-Stream(流数据,无地址) / ACE(缓存一致性) / CHI(AMBA5 总线,多核)
```

记住三个最常打交道的成员：**APB3/4、AHB-Lite、AXI4**。日常说的「APB 从机」「AXI 从机」默认指它们。

### 2.3 为什么三者共存：典型 SoC 三层拓扑

一颗真实 SoC 的总线永远长这样（你的 cnn_ram 是去掉 AXI 层的两层版，ZYNQ 是三层全占版）：

```
                        ┌────────┐ ┌────────┐ ┌────────┐
                        │CPU/CPU簇│ │GPU/NOC │ │ DMA    │   ← masters
                        └───┬────┘ └───┬────┘ └───┬────┘
        ════════════════════╪══════════╪══════════╪══════════════
             AXI 互连（主干，最高频/带宽，可能多级）
        ═══════════╤═════════════╤═══════════════╤═══════════════
                   │             │               │
             ┌─────┴────┐  ┌─────┴────┐   ┌─────┴──────┐
             │ DDR 控制器│  │ 高速外设  │   │ AXI2AHB 桥  │
             └──────────┘  └──────────┘   └─────┬──────┘
                                        ════════╪════════  AHB 高速域
                                          ┌─────┴─────┐
                                          │ SRAM/FLASH │
                                          │  AHB2APB 桥 │──▶ APB 外设域
                                          └───────────┘      ┌─────────┐
                                                             │UART GPIO │
                                                             │Timer I2C │
                                                             └─────────┘
```

**分层的原因只有一个：成本。**
- AXI 信号多、连线宽，挂一百个低速外设纯浪费面积；
- APB 简单省电，但拿它当 CPU 取指通路能急死人；
- 于是「快慢分治」：主干用 AXI，中间垫桥降速到 AHB，最外圈垫桥降到 APB。

**桥（Bridge）就是协议世界的变压器**——后面 4.8 你会看到 cnn_ram 里一个真实的 AHB2APB 桥怎么把 1 笔 AHB 传输展开成 APB 的两拍。

---

## 三、APB：一切从「让外设简单」开始

### 3.1 APB 解决什么问题

90 年代末的 SoC，外设（UART、GPIO、Timer）越挂越多。如果每个外设都直接挂在高速总线上，每个都要实现复杂的流水线接口——**外设本身很慢（配一次寄存器几微秒才生效），却要背一个高速接口的面积和功耗**。

APB 的答案：为慢速外设单独设计一条「傻瓜总线」。

- 接口信号少到极致，从机逻辑一个下午写得完；
- 所有信号只在 PCLK 一个时钟域，没有流水线，没有仲裁；
- 时钟可以跑得很慢甚至门控掉，省电。

### 3.2 信号清单（APB3/4 全家福）

| 信号 | 方向 | 宽度 | 说明 |
|------|------|------|------|
| PCLK | 全局 | 1 | 总线时钟 |
| PRESETn | 全局 | 1 | 低有效复位 |
| PADDR | M→S | 可配 | 地址 |
| PSEL | M→S | 1 | 从机选择（每个从机一根，来自地址译码） |
| PENABLE | M→S | 1 | ACCESS 相位指示（APB 的灵魂信号） |
| PWRITE | M→S | 1 | 1 写 0 读 |
| PWDATA | M→S | 数据宽 | 写数据 |
| PSTRB | M→S | 数据宽/8 | **APB4 新增**，逐字节写使能 |
| PRDATA | S→M | 数据宽 | 读数据 |
| PREADY | S→M | 1 | **APB3 新增**，从机就绪（插等待用） |
| PSLVERR | S→M | 1 | **APB3 新增**，错误响应 |

APB2 没有 PREADY/PSLVERR/PSTRB——从机永远零等待、永远不报错。面试如果被问「APB2 和 APB3 区别」，答这两组信号。

### 3.3 三相位状态机与逐拍时序

APB master 内部是一个三状态机（你 `17. apb/APB_Protocol_Guide.md` 里画的那个）：

```
            PSEL=0
   ┌──────┐        ┌──────────┐ PENABLE:0→1   ┌──────────┐
   │ IDLE │───▶────│  SETUP   │──────────────▶│  ACCESS  │
   └──────┘        └──────────┘                └────┬─────┘
      ▲                 ▲  PSEL=1                │  PREADY=1（传输完成）
      │                 └────────────────────────┘  │（有下一笔:回SETUP；无:回IDLE）
      └─────────────────────────────────────────────┘
```

**无等待写**（最基本情况，逐拍看）：

| 拍 | 相位 | PSEL | PENABLE | PADDR/PWRITE/PWDATA | PREADY |
|----|------|------|---------|--------------------|--------|
| T1 | SETUP | 1 | 0 | 有效（地址/方向/数据全给出） | ×（无意义） |
| T2 | ACCESS | 1 | 1 | 保持不变 | 1 |
| T2 上升沿后 | — | — | — | — | **写生效**（slave 在 T2 结束沿落寄存器） |

**无等待读**：一样，只是 slave 在 ACCESS 拍把 PRDATA 放出来，master 在 T2 沿采样：

| 拍 | PENABLE | PRDATA |
|----|---------|--------|
| T1 SETUP | 0 | × |
| T2 ACCESS | 1 | 有效，master 在 T2 沿采样 |

**含等待**（从机慢，PREADY 插等待）：

| 拍 | PSEL | PENABLE | PREADY | 说明 |
|----|------|---------|--------|------|
| T1 | 1 | 0 | × | SETUP，**不许等** |
| T2 | 1 | 1 | 0 | ACCESS 第 1 拍，从机没准备好 |
| T3 | 1 | 1 | 0 | 继续等（PENABLE 必须保持高） |
| T4 | 1 | 1 | 1 | 完成，写/读在 T4 沿生效 |

**背靠背**：PSEL 不撤、PENABLE 每 2 拍出现 1 个高拍，等于把下一笔的 SETUP 藏在上一笔的 ACCESS 之后：

```
拍:      T1     T2     T3     T4
PSEL:    ──1────1─────1─────1──
PENABLE: ──0────1─────0─────1──   ← T3 就是传输2的 SETUP
传输:      [S1][  A1  ][S2][  A2  ]
```

### 3.4 读你自己的代码：`17. apb/apb_slave.v`

你写的 APB3 从机里没有显式的三状态 FSM，而是用组合门控替代：

```verilog
// 17. apb/apb_slave.v —— 零等待从机可以不写状态机
wire access_valid = PSEL & PENABLE;        // 只在 ACCESS 拍为真
wire write_valid  = access_valid &  PWRITE;
wire read_valid   = access_valid & ~PWRITE;
```

为什么合法？**因为你 PREADY 恒 1（零等待）**——从机没有需要「记住」的状态，每一拍的行为完全由当前输入组合出来。

对比你的 TB（`apb_slave_tb.v`），master 侧 task 是严格两拍的：

```verilog
// SETUP：PSEL=1、PENABLE=0 一拍 → ACCESS：PENABLE=1，while(!PREADY) 等待
```

**同一套协议：slave 可以无状态（零等待时），master 必须按相位走。** 这就是 APB「对从机友好」的具体体现。

### 3.5 APB 的生存哲学

面试官爱问「APB 这么慢，为什么不淘汰掉」。答案分三层：

1. **配置访问不需要快**：外设寄存器一个微秒才动作，总线快 100 倍也白搭；
2. **省电**：时钟慢 + 接口简单，外设域时钟可以门控；
3. **省面积**：一百个外设 ×（几十根 vs 上百根信号 + 流水线逻辑），差距巨大。

所以 APB 活得很好——只是**退到了 SoC 最外圈**，通过桥挂在高速总线后面。

#### 面试表述

> 「APB 是 ARM 为低速外设定义的简单总线：无流水线、单主、每笔传输固定 SETUP+ACCESS 两拍起步。它的设计目标是接口极简和低功耗，而不是带宽——所以所有信号单相位有效，从机甚至可以不写状态机。现代 SoC 里 APB 位于最外圈外设域，通过 AHB2APB 或 AXI2APB 桥接入高速总线。APB3 加了 PREADY/PSLVERR 让从机能插等待、报错误，APB4 加了 PSTRB 支持字节写。」

深读请回到你自己的 `17. apb/APB_Protocol_Guide.md`（447 行，讲得已经很全）。

---

## 四、AHB：给总线装上流水线

### 4.1 APB 的瓶颈，AHB 的三个答案

APB 两拍搬一笔数据，且第二笔必须等第一笔完全结束。当总线要承载 **CPU 取指、访存、DMA 搬运**时，这就是灾难——CPU 一拍能处理一条指令，总线两拍才送一条指令过来，CPU 一半时间在挨饿。

AHB（Advanced High-performance Bus）给出三个答案：

| 痛点 | AHB 的答案 |
|------|-----------|
| 两拍一笔太慢 | **流水线**：地址相位和数据相位重叠，稳态一拍一笔 |
| 一个主设备不够用 | **多主仲裁**：HBUSREQ/HGRANT 申请-授权机制 |
| 一笔一笔发地址开销大 | **突发 burst**：HBURST 告诉从机「接下来连续 N 笔是连着的」 |

### 4.2 信号清单（AHB-Lite 从机视角）

| 信号 | 方向 | 宽度 | 说明 |
|------|------|------|------|
| HCLK / HRESETn | 全局 | 1 | 时钟 / 低有效复位 |
| HADDR | M→S | 可配 | 地址（**地址相位**有效） |
| HTRANS | M→S | 2 | 传输类型：`00 IDLE` / `01 BUSY` / `10 NONSEQ` / `11 SEQ` |
| HWRITE | M→S | 1 | 读写方向（**地址相位**有效） |
| HSIZE | M→S | 3 | 000=byte / 001=halfword / 010=word |
| HBURST | M→S | 3 | SINGLE/INCR/WRAP4/INCR4/... |
| HPROT | M→S | 4 | 保护属性（一般从机不管） |
| HWDATA | M→S | 32 | 写数据（**数据相位**有效！和 APB 不同） |
| HSEL | 译码→S | 1 | 从机选择 |
| HREADY | **矩阵→S（输入！）** | 1 | 总线全局就绪，详见 4.4 |
| HREADYOUT | S→矩阵 | 1 | 本从机就绪输出 |
| HRDATA | S→M | 32 | 读数据（数据相位有效） |
| HRESP | S→M | 1 | 0=OKAY / 1=ERROR |

注意和 APB 的两处关键差异：
- **APB 的 PADDR/PWRITE/PWDATA 全相位保持；AHB 的 HADDR/HWRITE 只在地址相位有效一拍，HWDATA 要到下一拍（数据相位）才出现**——这就是流水线的代价：从机必须自己把地址「记」一拍；
- APB 用 PENABLE 区分相位；AHB 用 **HTRANS + 时序位置**隐式表达相位。

### 4.3 两相位流水线逐拍时序

**单笔零等待读**（TB 里 `ahb_read` task 干的事）：

| 拍 | 相位 | HTRANS | HADDR | HRDATA |
|----|------|--------|-------|--------|
| T0 | 传输 A 地址相位 | NONSEQ | A 有效 | × |
| T1 | 传输 A 数据相位 | （IDLE） | × | **A 的数据**，master 在 T1 沿采样 |

**背靠背零等待流水线**（AHB 的满血状态，一拍完成一笔）：

| 拍 | HTRANS | HADDR | HWDATA/HRDATA | 完成情况 |
|----|--------|-------|---------------|---------|
| T0 | NONSEQ(A1) | A1 | — | — |
| T1 | NONSEQ(A2) | A2 | D1 ← A1 数据相位 | **A1 完成** |
| T2 | IDLE | — | D2 ← A2 数据相位 | **A2 完成** |

看清楚 T1 这一拍：**A1 的数据相位和 A2 的地址相位在同一拍**。这就是「重叠」。本目录 TB 的 `ahb_write_b2b` task 复现的正是这个时序，你可以跑完仿真打开 `sim/ahb_lite_slave_tb.vcd` 看 T1 拍的波形。

**插入等待**（从机慢）：从机拉低 HREADYOUT，总线上的一切（地址相位、数据相位）原地冻结：

| 拍 | dp 状态 | HREADYOUT | 效果 |
|----|---------|-----------|------|
| T1 | WAIT | 0 | A1 数据相位延长一拍，**A2 的地址相位也被冻结**（HREADY=0 期间地址不允许被采样） |
| T2 | OKAY | 1 | A1 完成，同拍 A2 地址相位被采样 |

### 4.4 HREADY vs HREADYOUT——面试大坑（必考）

这两个信号是 AHB 学习路上最大的绊脚石，用 cnn_ram 的真实连接讲：

```
                 ┌──────────────────────────────────┐
   Cortex-M0 ───▶│        AHB_BusMatrix_3x6         │
   (HADDR...)    │                                  │
                 │   SI0   SI1   SI2   (输入口)      │
                 │    \    |    /                   │
                 │     仲裁 + 译码 + 选路            │
                 │   /    |    \                    │
                 │  MI0   MI1 ... MI5   (输出口)    │
                 └───┬─────┬──────────┬─────────────┘
                     │     │          │
                 HSEL_P0 │        HSEL_P5
                 HADDR_P0│        HADDR_P5
                 HREADY_P0 (→)  HREADY_P5 (→)     ← 每个从机各自收到一份 HREADY
                     │     │          │
                  FLASH   SRAM     AHB_CNN (从机们)
                     │     │          │
                 HREADYOUT_P0 (←) HREADYOUT_P5 (←)  ← 每个从机各自输出
```

规则只有两句话：

- **HREADYOUT**：从机自己的就绪输出。「我这笔传输准备好了吗」。
- **HREADY**：从机的输入，**总线全局就绪**。多从机系统里它由互连/矩阵驱动——**当前被选中的那个从机的 HREADYOUT，经过矩阵回传给所有从机和 master**。

为什么这么设计？因为 AHB 是**共享总线**：任何时刻只有一条传输在流。任何从机没准备好，整条总线都得等。所以每个从机都要看到「全局的 HREADY」，才能知道「我记在寄存器里的地址什么时候作废、什么时候可以采下一个」。

落到 RTL（本目录 `rtl/ahb_lite_slave.v` 的写法，与 cnn_ram 的 cmsdk 例程一致）：

```verilog
// 地址相位采样：HREADY 为高（总线在前进）时才把地址打一拍
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) ...
    else if (HREADY) begin          // HREADY=0 时保持 → 地址相位被冻结
        ap_valid <= HSEL & HTRANS[1];
        ap_addr  <= HADDR;
        ...
    end
end
```

TB 里单从机直连，`wire HREADY = HREADYOUT;`（自己回传给自己）——真实系统里这一环由矩阵完成。

### 4.5 HSIZE 与 byte lane（对接 3.x 的 PSTRB）

AHB 写 32 位总线上的一个字节时，数据放在哪？**按 lane 对齐**：地址 0x09、HSIZE=byte，数据在 HWDATA[15:8]（lane 1）。

从机生成逐字节写使能（本目录 RTL，和 cnn_ram 的 `cmsdk_ahb_eg_slave_interface.v` 同款逻辑）：

```verilog
// HSIZE + 地址低 2 位 → 4 位字节选通
always @(*) begin
    case (ap_size[1:0])
        2'b00: case (ap_addr[1:0])          // byte：地址低位直接选 lane
            2'b00:   byte_lane = 4'b0001;
            2'b01:   byte_lane = 4'b0010;
            2'b10:   byte_lane = 4'b0100;
            default: byte_lane = 4'b1000;
        endcase
        2'b01:   byte_lane = ap_addr[1] ? 4'b1100 : 4'b0011;  // halfword
        default: byte_lane = 4'b1111;                           // word
    endcase
end
```

（AXI 时代这套逻辑变成显式的 WSTRB 信号——协议把「约定」升级成了「信号」，4.5 这段在 5.6 会再呼应。）

### 4.6 ERROR 两拍响应

AHB-Lite 从机报错的时序很特别：**HRESP=ERROR 的响应要占用两拍**（IHI 0033）：

| 拍 | HRESP | HREADYOUT | 含义 |
|----|-------|-----------|------|
| 数据相位第 1 拍 | 1 | **0** | 预告：要出错了，master 有机会取消下一笔 |
| 数据相位第 2 拍 | 1 | **1** | 传输正式以 ERROR 结束 |

为什么要两拍？因为零等待流水线里 master 可能在错误传输的数据相位已经发出了下一笔的地址——第一拍 ERROR+不就绪把流水线「顶住」，给 master 一拍反应时间，避免下一笔已经在飞才收到错误。

本目录 RTL 的实现是一个四状态小状态机（DP_OKAY/DP_WAIT/DP_ERR1/DP_ERR2），TB 场景 7 逐拍检查了这两拍——去看 `sim/ahb_lite_slave_tb.v` 的 Scenario 7。

### 4.7 AHB vs AHB-Lite vs AHB5

| 特性 | AHB（full） | AHB-Lite | AHB5 |
|------|-------------|----------|------|
| 多主 | ✔ 仲裁+HMASTER/SPLIT/RETRY | ✘ 单主（或外加矩阵） | ✔ |
| SPLIT/RETIRE | ✔（慢从机释放总线） | ✘ | ✘ |
| 典型用户 | 老设计 | **Cortex-M0/M3、你的 cnn_ram** | Cortex-M23/M33 |
| 与 AXI 关系 | — | — | 可与 ACE 互操作 |

一句话记忆：**AHB-Lite = 去掉多主和 SPLIT/RETRY 的 AHB**。SPLIT/RETRY 是让慢从机「让出总线别堵路」的机制，实现复杂，实践中被「加矩阵」取代——你要在 cnn_ram 里看到的 BusMatrix 就是干这个的。

### 4.8 cnn_ram 实战：一块真实的 AHB-Lite SoC

纸上谈兵到此为止，看你的 cnn_ram（`cnn_ram/Vivado/CM0_Proj/CM0_Proj.srcs/sources_1/imports/`）。这块 SoC 是教科书级的 AHB-Lite 案例：

**① 总线矩阵：3 个输入口 × 6 个输出口**

```
 cortexm0ds_logic (ARM M0, AHB master) ──── SI0 ─┐
 AHB_DMAC (你写的 DMA, AHB master)      ──── SI1 ─┤ AHB_BusMatrix_3x6_L1
                                                  ├─ 仲裁+译码+选路
                                                  ┤
                                                  └─ MI0..MI5
 MI0 → FLASH          0x0000_0000 + 128KB   (cmsdk_ahb_ram)
 MI1 → SRAM           0x2000_0000 + 128KB   (cmsdk_ahb_ram)
 MI2 → AHB_GPIO       0x3000_0000 + 8MB     (cmsdk_ahb_gpio)
 MI3 → DMAC_Config    0x3080_0000 + 8MB     (你写的 AHB slave)
 MI4 → APB 子系统      0x4000_0000 + 256MB  (cmsdk_apb_subsystem, 含 AHB2APB 桥)
 MI5 → AHB_CNN        0x6000_0000 + 256MB   (cmsdk_ahb_eg_slave 改造)
 其余地址 → 矩阵内置 default slave → 回 ERROR
```

矩阵内部的文件分工（都在 `imports/AHB_BusMatrix_3x6_L1/`）：

- `AHB_Arbiter_L1.v` —— 仲裁（多主抢同一个输出口时裁决）
- `AHB_Decoder_L1S0/S1/S2.v` —— 每个输入口一套地址译码（HADDR → HSEL_Pn）
- `AHB_Input_L1.v` / `AHB_Output_L1.v` —— 输入/输出级寄存

**这就是 4.4 那张 HREADY 回传图的真实实现**：每个输出口的 `HREADYOUT_Pn` 被矩阵收集、回传成全局 `HREADYSn`。

**② CNN 加速器的挂法：三层包装（最值得学的工程模式）**

```
 AHB 总线信号                    寄存器接口                    加速器本体
 HSEL/HADDR/HTRANS/...  ┌─────────────────┐  addr/wen/ren  ┌──────────┐
 HWDATA ───────────────▶│ ahb_eg_slave    │───────────────▶│ cnn_top  │
 HRDATA ◀───────────────│  ├ interface    │  wdata/rdata   │ (纯流式: │
 HREADYOUT/HRESP ◀──────│  └ reg          │  byte_strobe   │  无总线) │
                        └─────────────────┘                └──────────┘
```

- **外壳** `cmsdk_ahb_eg_slave.v`：只有 AHB 端口，不含业务；
- **翻译层** `cmsdk_ahb_eg_slave_interface.v`：把 AHB 两相位翻译成朴素的 `addr/write_en/read_en` 单拍寄存器接口（就是 4.2 那句「从机必须自己记地址一拍」的落地）；
- **寄存器层** `cmsdk_ahb_eg_slave_reg.v`：data0 写像素（bit8=valid 自动清零成单拍脉冲）、data1 读结果（bit8=done + 低 4 位识别结果）。

**核心思想：加速器本体完全不懂总线。** 换成 AXI 接口时只换前两层皮，`cnn_top` 一行不改。面试讲 CNN 项目时，这个「总线无关的内核 + 协议外壳」分层是你项目架构能力的直接证据。

**③ 自写 AHB master：`AHB_DMAC.v`**

你自己的 DMA 是 AHB master 的极简样本：状态机 `idle → wait_for_ready → read → write`，HPROT 恒 0011、HBURST 恒 SINGLE。master 侧要驱动什么？对照 4.2 的信号表：发 HADDR/HTRANS/HWRITE 的**地址相位**，在数据相位放 HWDATA、看 HREADY 收 HRDATA。

**④ AHB2APB 桥：`cmsdk_ahb_to_apb.v`（第三、四章的接缝）**

桥是这两个协议血缘关系的活化石。它的状态机：

```
 ST_IDLE ─收到AHB传输─▶ ST_APB_WAIT ─▶ ST_APB_TRNF(SETUP) ─▶ ST_APB_TRNF2(ACCESS) ─▶ 回 IDLE
   （对AHB侧:拉低HREADYOUT                （对APB侧:按APB协议
    假装自己是个慢从机）                     慢慢发两拍）
```

**1 笔 AHB 传输进来，桥在 APB 侧老老实实发 SETUP+ACCESS 两拍，APB 完成后桥才在 AHB 侧放行 HREADYOUT。** 对 AHB 主设备来说桥就是个「插了好几个等待态的从机」；对 APB 外设来说桥就是它的 master。协议差异被桥完全吸收——这就是 2.3 拓扑图里「桥是变压器」的意思。

### 4.9 本目录代码：`rtl/ahb_lite_slave.v`

把上面所有考点浓缩成 150 行的可默写模板，结构就五段：

```
 ①地址译码（组合） → ②地址相位采样（HREADY 门控打一拍）
 → ③数据相位状态机（OKAY直通/WAIT/ERR两拍） → ④byte-lane 生成 → ⑤寄存器堆+读多路
```

TB 覆盖 8 个场景（word/byte/half 写、等待插入、ERROR 两拍、背靠背流水线），运行：

```powershell
# Windows 本机 PowerShell，在 21. AMBA_Bus 目录下
.\scripts\run_all.ps1
```

#### 面试表述

> 「AHB 通过地址相位/数据相位重叠的流水线实现稳态一拍一笔传输，用 HBUSREQ/HGRANT 仲裁支持多主，用 HBURST 支持突发。从机设计上有三个关键点：一是地址只在地址相位有效、HWDATA 在下一拍才到，所以要用 HREADY 门控把地址打一拍；二是 HREADYOUT 是从机自己的就绪输出，HREADY 是矩阵回传的全局就绪，任何从机拉低 HREADYOUT 都会冻结整条流水线；三是 ERROR 响应占两拍，第一拍 HRESP=1+HREADYOUT=0 顶住流水线，第二拍才完成，给 master 取消下一笔的机会。」

---

## 五、AXI：把地址和数据彻底解开

### 5.1 AHB 的瓶颈，AXI 的答案

AHB 的流水线已经很快了，为什么还要 AXI？三个致命伤，全都可以归结为「**共享总线 + 强耦合**」：

1. **任何从机都能堵死全队**：一条共享总线，一个慢从机插等待，所有主设备一起停（4.3 的冻结机制）；
2. **outstanding = 1**：master 必须等上一笔完成才能发下一笔地址——发给 DDR 这种延迟几十拍的从机时，master 全程罚站；
3. **频率上不去**：地址→数据→响应强耦合的组合路径横跨整个总线域，频率越高时序越难收敛。

AXI4（2003 年随 AMBA3 面世）的答案干脆利落：**把一次传输拆成五个独立通道，各通道各自握手、各自打拍**。

### 5.2 五通道架构

```
   写地址 AW ─────────────▶ ┐
   写数据 W  ─────────────▶ ├─ 从机收齐 AW+W → 执行写
   写响应 B  ◀───────────── ┘  完成后回 B
   读地址 AR ─────────────▶ ┐
   读数据 R  ◀───────────── ┘  从机收到 AR → 稍后回 R（可多拍）
```

| 通道 | 方向 | 关键信号 | 说明 |
|------|------|---------|------|
| AW | M→S | AWADDR/AWLEN/AWSIZE/AWBURST/**AWID**/AWVALID/AWREADY | 写地址（含 burst 控制信息） |
| W | M→S | WDATA/**WSTRB**/WLAST/WVALID/WREADY | 写数据（一拍一个 beat，WLAST 标尾） |
| B | S→M | **BID**/BRESP/BVALID/BREADY | 写响应（一笔 burst 一个） |
| AR | M→S | ARADDR/ARLEN/ARSIZE/ARBURST/**ARID**/ARVALID/ARREADY | 读地址 |
| R | S→M | RDATA/**RID**/RRESP/RLAST/RVALID/RREADY | 读数据（RLAST 标尾） |

先记住一个总纲：**AXI4-Lite 是 AXI4 砍掉 burst/ID/WLAST 后的寄存器配置专用子集**，五个通道和握手规则一模一样。所以 5.3–5.5 学的握手是两者通用的。

### 5.3 握手铁律（死锁警戒线）

每个通道都是同一套 VALID/READY 握手，规则三条：

1. **VALID 一旦拉高，必须保持到握手完成（看到 READY），不许中途撤回、不许改 payload**；
2. **READY 可以等 VALID（看清楚对方要什么再收），也可以自己先拉高（永远就绪）**；
3. **VALID 绝不允许依赖 READY**——不允许「你不 READY 我就不 VALID」。

第 3 条是死锁警戒线：如果 master 说「你先 READY 我才 VALID」，slave 说「你先 VALID 我才 READY」，两边互相等，总线死锁。本目录 `rtl/axi_lite_slave.v` 的写法就是标准示范：

```verilog
// READY 只看自己的缓冲状态，绝不看对方 VALID
assign AWREADY = ~aw_pend & ~b_valid;   // 我没在等 W、上一笔响应没挂着 → 随时能收
assign WREADY  = ~w_pend  & ~b_valid;
```

### 5.4 通道依赖关系

五通道彼此独立，但有三条硬依赖（IHI 0022 的 dependency rules）：

```
 AW握手完成 ──┐
              ├──▶ 才允许 BVALID   （写响应必须等地址和数据都到齐）
 W握手完成 ───┘
 AR握手完成 ───▶ 才允许 RVALID   （读数据必须等读地址握手）
```

另两条常被追问：
- **W 通道的最后一个 beat（WLAST=1）不必等 AW**——数据和地址谁先走完都行，但从机发 B 前要等到两者；
- 读通道和写通道之间**没有任何顺序约束**——一笔写还没回 B，一笔读的数据可以先回来（这就是「读比写先完成」，Q17）。

### 5.5 outstanding / 乱序 / 交错（AXI 的灵魂，面试必考）

三个词一张图分清：

```
 master 发出 AR(id=0) ─────────────────────────────▶ 从机
 master 发出 AR(id=1) ──────▶ 从机           ← outstanding：不等 R 回来就连发第 2 笔
                              ...
 slave  回 R(id=1)  ◀────────                ← 乱序：后发的先回（不同 ID 才允许！）
 slave  回 R(id=0)  ◀────────────────────────
```

- **outstanding（并行未决）**：master 不等响应连续发多笔传输。实现 = master 里开个深度 N 的 FIFO 记在途请求，从机同理。AHB 做不到（共享总线一次一笔）；
- **乱序（out-of-order）**：完成顺序 ≠ 发出顺序。**前提：必须不同 ID**。规范规定**同 ID 必须保序**——这是软件正确性的底线（想想两个核通过同 ID 读写同一个锁变量）；
- **交错（interleave）**：不同 burst 的 W 数据 beat 混在一起发（AXI3 有 WID 支持，**AXI4 删掉了 WID，写数据不允许交错**——这也是 AXI3 vs AXI4 的考点，见 5.7）。

为什么 outstanding 是 AXI 的灵魂？算一笔账就懂：DDR 延迟 30 拍。无 outstanding（AHB）：发一笔 → 等 30 拍 → 再发。有 outstanding=8：8 笔全部在途，30 拍等待被 8 笔摊薄，带宽利用率 ×8。**DDR/PCIe/NIC 这些高延迟从机，没有 outstanding 就是灾难。**

### 5.6 burst 详解

AXI4 的 burst 由三要素描述（都在 AW/AR 通道）：

| 信号 | 含义 |
|------|------|
| AxLEN | beat 数 - 1（AXI4：0~255，即最多 256 beat；AXI3 只到 16） |
| AxSIZE | 每个 beat 的字节数（2^SIZE） |
| AxBURST | FIXED / INCR / WRAP |

三种 burst 的行为：

```
FIXED:  地址恒定    A A A A        → FIFO 口、固定寄存器的场景
INCR:   地址递增    A A+4 A+8 ...  → 普通内存搬运（最常用）
WRAP:   到界回卷    ... 0x38, 0x3C, [回卷] 0x30, 0x34  → cache line 预取
```

**WRAP 的存在理由**：CPU 要地址 0x38 的数据，但 cache line 是 0x30~0x3F 整块。WRAP burst 从 0x38 开始发，搬完 0x38/0x3C 后**自动回卷**补齐 0x30/0x34——CPU 最想要的字最先到（critical word first），又不用拆成两次传输。约束：WRAP 的起始地址必须对齐到 `SIZE×LEN` 的边界。

**窄传输（narrow transfer）**：32 位总线上发 8 位数据。数据按 lane 对齐放在总线上（和 4.5 的 AHB byte lane 同源），WSTRB 逐 beat 标注哪些字节有效：

```
 beat0: WSTRB=0001, WDATA[.. byte0 ..]   ← 只写 lane0
 beat1: WSTRB=0010, WDATA[.. byte1 ..]
```

WSTRB 是 AXI 把 AHB 4.5 那套「HSIZE+地址组合生成写使能」的**隐式约定**升级成的**显式信号**——从机不再需要自己算 lane，照着 WSTRB 写就行。

### 5.7 AXI3 vs AXI4 vs AXI4-Lite vs AXI-Stream

| 特性 | AXI3 | AXI4 | AXI4-Lite | AXI4-Stream |
|------|------|------|-----------|-------------|
| burst 长度 | ≤16 | **≤256** | 无 burst | 无限流 |
| 写 ID | AWID+WID | AWID（**WID 删除**） | 无 ID | 无 ID |
| 写数据交错 | 支持（靠 WID） | **禁止** | — | — |
| QoS / REGION | 无 | 有 | 无 | — |
| 用途 | 老设计 | 主流 | 寄存器配置 | 流数据（无地址） |

AXI3→4 的「删 WID、禁交错」是拿写带宽的极致换设计简化——实践证明不值得为交错增加的复杂度买单。

AXI4-Lite 的定位是**「APB 的 AXI 版」**：单笔、无 burst、无 ID，专挂配置寄存器。APB 和 AXI4-Lite 功能重叠，选型看生态：AXI 主干 SoC 里直接挂 Lite（少一层桥），外设域还是 APB（省电）。

### 5.8 响应码

AXI 响应 2 位，四个值（AHB 只有 1 位 OKAY/ERROR）：

| 编码 | 名称 | 含义 |
|------|------|------|
| 00 | OKAY | 正常 |
| 01 | EXOKAY | 独占访问成功（AXI4 原子操作，Lite 不支持） |
| 10 | SLVERR | 从机错误（越界、写只读、内部错误）——对应 AHB 的 ERROR |
| 11 | DECERR | **互连**译码错误（地址没有目的地）——由互连报告，不是从机 |

DECERR 和 SLVERR 的分工面试常考：**SLVERR 是「从机说错了」，DECERR 是「互连说这地址根本没人认领」**。回忆 cnn_ram 矩阵里那个 default slave——未映射地址回 ERROR，它扮演的就是 DECERR 的角色。

### 5.9 本目录代码：`rtl/axi_lite_slave.v`

200 行覆盖 AXI-Lite 从机的全部面试考点。最值得背的是 **AW/W 双顺序处理**（AXI 面试手撕题的标配）：

```verilog
reg aw_pend, w_pend;          // 谁先到谁先 pend 住，等另一个
// AW 先到：aw_pend=1，锁存 awaddr_q；W 先到：w_pend=1，锁存 wdata_q/wstrb_q
wire wr_commit = aw_pend & w_pend & ~b_valid;   // 两个都到齐 → 执行写 + 挂 BVALID

always @(posedge ACLK or negedge ARESETn) begin
    if (!ARESETn) ...
    else begin
        if (aw_fire) begin aw_pend <= 1'b1; awaddr_q <= AWADDR; ... end
        if (w_fire)  begin w_pend  <= 1'b1; wdata_q  <= WDATA;  ... end
        if (wr_commit) begin
            aw_pend <= 1'b0; w_pend <= 1'b0;
            b_valid <= 1'b1;                          // BVALID 保持到 BREADY
            bresp_q <= aw_err_q ? RESP_SLVERR : RESP_OKAY;
        end else if (b_fire) b_valid <= 1'b0;
    end
end
```

TB 的十个场景把协议规则全部变成了断言：AW 先到/W 先到/同拍、BVALID/RVALID 在 READY 缺席时的保持、BVALID 期间 AWREADY 拉低、SLVERR……跑 `.\scripts\run_all.ps1` 看 `[PASS]` 列表，每一条 PASS 对应一条协议规则。

### 5.10 为什么 AXI 适合高频

把 5.1 的三个死结逐个解开：

1. **慢从机不再堵全队**：各主各发各的通道，互连按端口交换，慢端口只堵它自己那条线；
2. **outstanding 摊平延迟**（5.5）；
3. **关键：每个通道都可以独立插寄存器切片（register slice）**。AHB 的地址→数据→响应是横跨总线的一条强耦合组合路径，频率高不了；AXI 五通道各自独立握手，互连在每个通道上打一拍寄存器，时序路径被切短——**这就是「AXI 是为高频而生」的具体含义**。代价是延迟 +1 拍，但吞吐不降（流水线照常每拍一笔）。

### 5.11 你手里的 AXI：ZYNQ 与 e203

- **XC7Z020 的 PS（Processing System）**就是 AXI 主干：ARM 核通过 **AXI GP 口**（通用，接 PL 逻辑寄存器）和 **AXI HP 口**（高带宽，直连 DDR）与 FPGA 侧交互。你做 e203 移植时，PL 里的 AXI 互连、BRAM 控制器走的全是 AXI4——**那部分经验在面试里要主动往 AXI 协议细节上引**（比如「HP 口的 outstanding 深度」「跨 PS/PL 的 CDC 与 AXI 时钟」）。
- AXI4-Stream 在 ZYNQ 里同样常见：数据流（视频、网络）不走地址，只走 `TVALID/TREADY/TDATA/TLAST`——它就是五通道里抽出的单通道握手，学会 5.3 的握手等于学会了一半 Stream。

#### 面试表述

> 「AXI 把一次传输拆成 AW/W/B/AR/R 五条独立握手通道：写响应 B 必须等 AW 和 W 都握手完成，读数据 R 必须等 AR 握手；读和写通道之间没有顺序约束。每条通道遵循 VALID/READY 握手规则——VALID 一旦拉高保持到握手，READY 可以等 VALID 但 VALID 绝不能等 READY，否则死锁。凭借独立 ID，master 可以 outstanding 多笔在途传输、从机可以乱序完成（同 ID 保序），这解决了 AHB 一次只能有一笔在途、慢从机冻结整条总线的问题；同时五通道各自可以插寄存器切片，时序路径短，适合高频设计。AXI4 相比 AXI3 删了 WID、禁止写交错、burst 上限到 256。」

---

## 六、三协议横向对比总表

一张表收束全篇，面试前扫一眼：

| 维度 | APB | AHB-Lite | AXI4 |
|------|-----|----------|------|
| 传输单元 | 单笔 | 单笔/burst | burst（Lite 为单笔） |
| 流水线 | 无（2 拍/笔起） | 地址/数据两相位重叠 | 五通道各自独立流水 |
| 一笔完成 | ≥2 拍 | 零等待 1 拍 | 握手流水，稳态 1 beat/拍 |
| 多主 | 单主 | 仲裁器（HBUSREQ/HGRANT） | 天然多主（ID 区分） |
| 等待机制 | PREADY（仅 ACCESS 相位） | HREADYOUT→矩阵→HREADY | 各通道 READY 独立 |
| 错误响应 | PSLVERR（1 拍） | HRESP=ERROR（2 拍） | SLVERR/DECERR/EXOKAY |
| 字节写 | PSTRB（APB4） | HSIZE+地址隐式生成 | WSTRB 显式信号 |
| 乱序/并行 | ✘ | ✘ | ✔ outstanding+乱序 |
| burst | ✘ | HBURST（SINGLE/INCR/WRAP） | AxLEN+AxBURST（≤256） |
| 从机状态 | 可无状态（零等待） | 记地址 1 拍+dp 状态机 | 每通道独立握手逻辑 |
| SoC 位置 | 最外圈外设域 | 中间高速域/MCU 主干 | 高频高带宽主干 |
| 规范 | IHI 0024 | IHI 0033 | IHI 0022 |

---

## 七、面试速记 Q&A

以下按「先给结论、再给依据」的口径整理，可直接背。

**Q1：APB 一次传输几拍？为什么固定两拍起步？**
≥2 拍：SETUP 一拍 + ACCESS 一拍（PREADY 可延长）。SETUP 让从机有完整一拍做译码和准备，PENABLE 在 ACCESS 才拉高，保证写信号 / 读数据只在确定相位动作，从机不用处理任何流水线边界情况——用速度换简单。

**Q2：APB 的 SETUP 拍能不能插等待？**
不能。PREADY 只在 ACCESS 相位有意义，SETUP 固定一拍。等待只能发生在 PENABLE=1 之后。（追问「APB2 呢」：APB2 连 PREADY 都没有，永远零等待。）

**Q3：PSLVERR 什么时候拉？**
仅在 ACCESS 相位（PSEL&PENABLE&PREADY 都为高时采样）。典型场景：写只读寄存器、地址越界。

**Q4：AHB 和 APB 最本质的区别？**
流水线。AHB 地址相位和数据相位重叠，稳态一拍完成一笔；APB 串行两拍。附带推论：AHB 从机必须把地址相位信息打一拍寄存（HWDATA 晚地址一拍出现），APB 从机不用。

**Q5：HREADY 和 HREADYOUT 的区别？（最高频坑题）**
HREADYOUT 是从机自己的就绪输出；HREADY 是从机收到的**全局**就绪输入，由互连/矩阵把当前选中从机的 HREADYOUT 回传生成。任何从机拉低 HREADYOUT → 全局 HREADY=0 → 整条总线（包括地址相位）冻结。单从机系统里 HREADY 就是 HREADYOUT 接回来。

**Q6：HTRANS 四种编码？BUSY 什么时候用？**
IDLE（无传输）/ BUSY（master 在 burst 中间暂停一拍，从机必须零等待 OKAY 且不动作）/ NONSEQ（burst 第一笔或独立单笔）/ SEQ（burst 后续笔）。从机判有效传输只看 HTRANS[1]（NONSEQ/SEQ）。

**Q7：AHB 零等待流水线怎么工作？**
T0 发 A1 地址，T1 拍同时是 A1 数据相位和 A2 地址相位——地址链和数据链错位一拍并行推进，每拍完成一笔。慢从机拉低 HREADYOUT 时两链一起原地冻结。

**Q8：AHB 的 ERROR 为什么占两拍？**
第一拍 HRESP=1+HREADYOUT=0：顶住流水线，给 master 机会取消/调整已经在地址相位的下一笔；第二拍 HRESP=1+HREADYOUT=1：错误传输正式结束。

**Q9：HSIZE 和 byte lane 怎么生成写使能？**
数据按 lane 对齐放总线（写 0x09 的字节，数据在 HWDATA[15:8]），从机用 HSIZE[1:0]+HADDR[1:0] 组合出 4 位字节选通：byte→地址低位选 lane，half→[1] 选半字，word→全选。

**Q10：AHB2APB 桥怎么工作？**
对 AHB 侧装作慢从机（拉低 HREADYOUT 插等待），对 APB 侧装作 master（老老实实发 SETUP+ACCESS 两拍），APB 完成后回 HREADYOUT 放行。一笔 AHB 传输至少展开成 2 个 APB 拍。

**Q11：AXI 为什么读写地址通道要分开（AW/AR）？**
让读和写完全并行：master 可以同时发一笔写（AW）和一笔读（AR），互不阻塞。AHB 共享一条地址相位，读写必须串行。

**Q12：AXI 握手规则？什么情况死锁？**
VALID 拉高后保持到 READY 出现，payload 不变；READY 可以等 VALID；VALID 不能等 READY。若两端都坚持「对方先就绪」，握手永不发生——死锁。设计从机时 READY 只取决于自身缓冲状态。

**Q13：outstanding 是什么？怎么实现？和乱序什么关系？**
outstanding = master 不等响应连续发多笔在途传输（master/slave 各维护深度 N 的在途 FIFO，记录 ID 和信息）。乱序 = 完成顺序与发出顺序不同，**只有不同 ID 才允许乱序，同 ID 强制保序**。outstanding 是前提，乱序是可选结果（从机有能力时才乱序）。

**Q14：AXI3 和 AXI4 的区别？**
① burst 上限 16→256；② 删 WID → 写数据不允许交错（AXI3 靠 WID 支持交错）；③ 新增 QoS、REGION 信号；④ 默认更严格的其他时序约束。一句话：AXI4 用「禁交错」换简化，用「256 burst」喂 DDR。

**Q15：WRAP burst 干什么用的？**
cache line 预取。要的关键字最先返回（critical word first），到 `SIZE×LEN` 边界自动回卷补齐整条 line，CPU 不用先算 line 起点再拆两次传输。起始地址必须对齐边界。

**Q16：AXI4-Lite 和 AXI4、APB 的关系？**
Lite = AXI4 砍掉 burst/ID/WLAST（固定单笔、无 ID）的子集，专做寄存器配置；与 APB 功能重叠，选型看挂在哪条主干、少过几层桥。

**Q17：一笔写在途时，一笔读的数据能先回来吗？**
能。AXI 读通道和写通道之间没有顺序约束，只要求 R 等 AR、B 等 AW+W。（AHI/AHB 时代这是不可想象的。）

**Q18：AXI 为什么能跑更高频率？**
五通道独立握手 → 互连在每个通道上插寄存器切片，把 AHB 那条「地址→数据→响应」的长组合路径切成短段。代价每通道 +1 拍延迟，吞吐不变（每拍仍能传一个 beat）。

---

## 八、常见误区

**误区一：「APB 是 AHB 的简化版/子集」**
不是包含关系，是兄弟关系、定位不同。信号语义都不同：APB 用 PENABLE 显式标相位、全部信号全相位保持；AHB 用 HTRANS+时序位置隐式标相位、地址只有效一拍。正确的说法是「APB 和 AHB 各管一个速度域，桥负责翻译」。

**误区二：「AXI 就是 AHB 换个名字，也有地址相位数据相位」**
AXI 没有全局的地址相位/数据相位概念。五通道各自独立握手，AW 完成和 W 完成可以差任意拍，B 更晚——「一次传输」在时间上是打散的。拿 AHB 的两相位思维写 AXI 从机会在 AW/W 双顺序上直接翻车（5.9 的 pend 写法就是正解）。

**误区三：「HREADY 是从机的输出」**
反了。从机输出的是 HREADYOUT；HREADY 是从机的**输入**（矩阵回传的全局就绪）。方向搞反，画出的框图连不上（Q5）。

**误区四：「outstanding 就是乱序」**
outstanding 是「允许多笔在途」，乱序是「完成顺序可变」。从机可以 outstanding 但顺序完成（比如单口 SRAM），也可以乱序（比如多 bank DDR）。乱序必须不同 ID，同 ID 永远保序。

**误区五：「写数据和写地址必须同时有效」**
AW 和 W 是两条独立通道，各自握手，谁先谁后、隔几拍都合法。从机要么用 pend 标志等齐（本目录写法），要么用小 FIFO。TB 场景 2/3/4 分别验证了 AW 先到、W 先到、同拍三种情况。

---

## 九、一句话收尾 + 下一步学习

> **APB 教会我们「简单就是美」，AHB 教会我们「流水线是性能之源」，AXI 教会我们「解耦才能并行」。三层协议串起来，就是一部「需求推着协议走」的设计史——面试官想听的，正是你能不能讲出这条因果链。**

下一步学习路线（按性价比排序）：

1. **动手**：跑通本目录 `.\scripts\run_all.ps1`，打开两个 VCD 对照本篇的逐拍时序看波形；然后不看参考，白板重写 `axi_lite_slave.v` 的 AW/W 双顺序段；
2. **进阶项目（可作为目录 22）**：写一个支持 INCR burst + outstanding(深度4) 的 AXI4-Full 从机——把 5.5/5.6 从「懂了」变成「写过」；
3. **验证视角**：给本目录从机加 SVA 断言（`AWREADY |-> ##[1:$] ...` 之类的握手性质）——顺便推进你的 SV 学习线；
4. **生态**：了解 ACE/CHI 一句话（缓存一致性/多核互连），面试被问「AXI 之后是什么」时有话说；Xilinx PG059（AXI Interconnect 文档）是工程视角的好读物；
5. **回到你的板子**：下次在 XC7Z020 上跑 e203 时，用 ILA 抓一次 AXI GP 口的写握手，对着 5.3 的规则逐信号确认——协议从纸面落到硅片，才真正是你的。

---

*参考规范：ARM IHI 0024 (AMBA APB)、IHI 0033 (AMBA AHB-Lite)、IHI 0022 (AMBA AXI)。*

*本目录配套代码：`rtl/ahb_lite_slave.v`、`rtl/axi_lite_slave.v`、`sim/ahb_lite_slave_tb.v`、`sim/axi_lite_slave_tb.v`、`scripts/run_all.ps1`（iverilog 仿真全 PASS）。*
