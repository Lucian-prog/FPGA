# APB 协议详解 (AMBA Advanced Peripheral Bus)

> 学习目标：理解 APB 协议原理，为手写 APB Slave / Master 打基础

---

## 一、APB 在 AMBA 总线体系中的位置

```
┌─────────────────────────────────────────────────────┐
│                     SoC 芯片内部                     │
│                                                     │
│              ┌──────┐                               │
│              │ CPU  │                               │
│              └──┬───┘                               │
│                 │                                   │
│  ══════════════════════════════  AXI/AHB 高速总线   │
│        │              │              │              │
│     ┌──┴──┐        ┌──┴──┐       ┌──┴──┐           │
│     │ DMA │        │ RAM │       │ APB │           │
│     └─────┘        └─────┘       │ 桥  │           │
│                                  └──┬──┘           │
│                    ══════════════════════  APB 低速  │
│                       │        │       │            │
│                    ┌──┴─┐  ┌───┴┐  ┌──┴──┐         │
│                    │UART│  │I2C │  │GPIO │         │
│                    └────┘  └────┘  └─────┘         │
└─────────────────────────────────────────────────────┘
```

| 总线 | 用途 | 特点 |
|------|------|------|
| AXI  | CPU ↔ DDR / 高速IP | 高带宽、支持乱序、多通道 |
| AHB  | CPU ↔ 中速外设 | 流水线、单周期传输 |
| **APB** | **桥 ↔ 低速外设** | **简单、低功耗、最少2周期** |

---

## 二、APB 信号定义

```
          APB Master（桥接器）                APB Slave（外设）
          ┌─────────────────┐                ┌─────────────────┐
          │                 │                │                 │
          │   PCLK     ─────┼───────────────►│                 │
          │   PRESETn  ─────┼───────────────►│                 │
          │   PADDR    ─────┼───────────────►│                 │
          │   PSEL     ─────┼───────────────►│                 │
          │   PENABLE  ─────┼───────────────►│                 │
          │   PWRITE   ─────┼───────────────►│                 │
          │   PWDATA   ─────┼───────────────►│                 │
          │   PSTRB    ─────┼───────────────►│  (APB3新增)     │
          │   PPROT    ─────┼───────────────►│  (APB3新增)     │
          │                 │                │                 │
          │   PRDATA   ─────┼◄───────────────│                 │
          │   PREADY   ─────┼◄───────────────│                 │
          │   PSLVERR  ─────┼◄───────────────│  (APB3新增)     │
          │                 │                │                 │
          └─────────────────┘                └─────────────────┘
```

### 信号详解

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `PCLK`    | M→S | 1  | 总线时钟，所有信号在**上升沿**采样 |
| `PRESETn` | M→S | 1  | **低电平**有效复位 |
| `PADDR`   | M→S | 32 | 地址总线 |
| `PSEL`    | M→S | 1  | 片选，选中某个 Slave |
| `PENABLE` | M→S | 1  | 第二周期置高，指示传输进入 ACCESS 阶段 |
| `PWRITE`  | M→S | 1  | `1`=写，`0`=读 |
| `PWDATA`  | M→S | 32 | 写数据 |
| `PSTRB`   | M→S | 4  | 字节选通，`PSTRB[n]=1` 表示第 n 字节有效（APB3）|
| `PRDATA`  | S→M | 32 | 读数据 |
| `PREADY`  | S→M | 1  | Slave 就绪，`0`=插入等待周期 |
| `PSLVERR` | S→M | 1  | Slave 错误响应（APB3）|

---

## 三、APB 状态机（核心！）

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    │         ┌──────────┐                │
                    │  复位后 │          │                │
                    │ ───────►│   IDLE   │                │
                    │         │          │                │
                    │         └────┬─────┘                │
                    │              │                      │
                    │   PSEL=1     │                      │
                    │   有传输请求  │                      │
                    │              ▼                      │
                    │         ┌──────────┐                │
                    │         │          │ PENABLE=0      │
                    │         │  SETUP   │ 第 1 周期      │
                    │         │          │                │
                    │         └────┬─────┘                │
                    │              │                      │
                    │         下个时钟上升沿               │
                    │              ▼                      │
                    │         ┌──────────┐                │
                    │  ┌──────│          │ PENABLE=1      │
                    │  │      │  ACCESS  │ 第 2 周期      │
                    │  │      │          │                │
                    │  │      └────┬─────┘                │
                    │  │           │                      │
                    │  │PREADY=0   │ PREADY=1             │
                    │  │继续等待   │ 传输完成             │
                    │  └──────────►│                      │
                    │              │                      │
                    │    无下一个传输──►IDLE               │
                    │    有下一个传输──►SETUP              │
                    │                                     │
                    └─────────────────────────────────────┘
```

### 三个状态说明

| 状态 | PSEL | PENABLE | 描述 |
|------|:----:|:-------:|------|
| **IDLE**   | 0 | 0 | 空闲，无传输 |
| **SETUP**  | 1 | 0 | 建立期，ADDR/WRITE/DATA 已稳定，持续**1周期** |
| **ACCESS** | 1 | 1 | 访问期，Slave 执行操作；PREADY=0 时保持此状态 |

---

## 四、时序图

### 4.1 无等待写传输

```
         T1    T2    T3    T4
PCLK   : ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
          └─┘ └─┘ └─┘ └─┘

PSEL   :       ┌─────┐
         ──────┘     └──────

PENABLE:             ┌──┐
         ────────────┘  └───

PWRITE :       ┌─────┐          (写 = 1)
         ──────┘     └──────

PADDR  :       ┌ADDR─┐
         ──────┘     └──────

PWDATA :       ┌DATA─┐
         ──────┘     └──────

PREADY :  ──────────────────   (Slave 始终 ready)

状态   : IDLE  SETUP  ACCESS  IDLE
                 ↑      ↑
               T2建立  T3写入完成
```

### 4.2 含等待周期写传输（PREADY=0）

```
         T1    T2    T3    T4    T5
PCLK   : ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
          └─┘ └─┘ └─┘ └─┘ └─┘

PSEL   :       ┌───────────┐
         ──────┘           └───

PENABLE:             ┌─────┐
         ────────────┘     └───

PREADY :  ───────────┐  ┌─────   ← T3 未就绪，T4 就绪
                      └──┘

PWDATA :       ┌─────DATA──┐
         ──────┘           └───

状态   : IDLE SETUP  ACCESS  ACCESS  IDLE
                      ←等待→   完成
```

### 4.3 无等待读传输

```
         T1    T2    T3    T4
PCLK   : ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
          └─┘ └─┘ └─┘ └─┘

PSEL   :       ┌─────┐
         ──────┘     └──────

PENABLE:             ┌──┐
         ────────────┘  └───

PWRITE :  ──────────────────   (读 = 0，保持低)

PADDR  :       ┌ADDR─┐
         ──────┘     └──────

PRDATA :             ┌DATA┐
         ────────────┘    └──   ← Slave 在 ACCESS 阶段输出

PREADY :  ──────────────────   (始终 ready)

状态   : IDLE  SETUP  ACCESS  IDLE
```

### 4.4 连续写传输（背靠背）

```
         T1    T2    T3    T4    T5
PCLK   : ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
          └─┘ └─┘ └─┘ └─┘ └─┘

PSEL   :       ┌───────────┐
         ──────┘           └───

PENABLE:             ┌──┐  ┌──
         ────────────┘  └──┘

PADDR  :       ┌ADDR1┬ADDR2┐
         ──────┘     │     └───

PWDATA :       ┌DATA1┬DATA2┐
         ──────┘     │     └───

状态   : IDLE SETUP ACCESS SETUP ACCESS
                ↑第1次传输 ↑第2次传输
```

---

## 五、多 Slave 地址译码

```
          AHB-APB 桥接器（唯一 Master）
                     │
               PADDR[31:0]
                     │
          ┌──────────┴──────────────┐
          │        地址译码器        │
          │                         │
          │  0x4000_0000~0x0FFF → PSEL[0]=1  │
          │  0x4000_1000~0x1FFF → PSEL[1]=1  │
          │  0x4000_2000~0x2FFF → PSEL[2]=1  │
          └──────┬──────────┬───────┬─────────┘
                 │          │       │
              PSEL[0]   PSEL[1]  PSEL[2]
                 │          │       │
           ┌─────┴──┐  ┌────┴─┐  ┌─┴────┐
           │  UART  │  │ I2C  │  │ GPIO │
           └────────┘  └──────┘  └──────┘

注意：所有 Slave 共享 PADDR / PWRITE / PWDATA / PENABLE
      只有 PSEL[x] 各自独立
```

---

## 六、Slave 内部寄存器结构

```
        APB Slave 内部（以 UART 为例）
        ┌────────────────────────────────────────┐
        │                                        │
        │  PADDR[7:2]  (字对齐地址选择)           │
        │       │                                │
        │       ▼                                │
        │  ┌────────────────────────────────┐    │
        │  │           地址译码              │    │
        │  └──┬──────────┬────────┬─────────┘   │
        │     │          │        │              │
        │   0x00       0x04     0x08             │
        │     │          │        │              │
        │  ┌──┴───┐  ┌───┴──┐  ┌──┴───┐         │
        │  │CTRL  │  │STATUS│  │ DATA │         │
        │  │(R/W) │  │(R)   │  │(R/W) │         │
        │  └──────┘  └──────┘  └──────┘         │
        │   波特率     发送忙     收发数据          │
        │                                        │
        └────────────────────────────────────────┘
```

### 字节对齐寻址

```verilog
// APB 地址按 4 字节对齐（PADDR[1:0] 始终为 00）
// 用 PADDR[7:2] 做寄存器选择

case (PADDR[7:2])
    6'h00: // 寄存器 0，偏移 0x00
    6'h01: // 寄存器 1，偏移 0x04
    6'h02: // 寄存器 2，偏移 0x08
endcase
```

---

## 七、APB Slave 代码模板

```verilog
module apb_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
)(
    // ── APB 接口 ──────────────────────────
    input                        PCLK,
    input                        PRESETn,
    input  [ADDR_WIDTH-1:0]      PADDR,
    input                        PSEL,
    input                        PENABLE,
    input                        PWRITE,
    input  [DATA_WIDTH-1:0]      PWDATA,
    input  [DATA_WIDTH/8-1:0]    PSTRB,
    output reg [DATA_WIDTH-1:0]  PRDATA,
    output                       PREADY,
    output                       PSLVERR
);

// ── 内部寄存器 ────────────────────────────
reg [DATA_WIDTH-1:0] reg_ctrl;   // 0x00 控制
reg [DATA_WIDTH-1:0] reg_stat;   // 0x04 状态（只读）
reg [DATA_WIDTH-1:0] reg_data;   // 0x08 数据

// ── 传输有效信号 ───────────────────────────
// 关键：必须 PSEL && PENABLE 同时为高才是 ACCESS 阶段
wire trans_valid = PSEL & PENABLE;
wire write_en    = trans_valid &  PWRITE;
wire read_en     = trans_valid & ~PWRITE;

// ── 固定输出（可扩展为带等待） ─────────────
assign PREADY  = 1'b1;
assign PSLVERR = 1'b0;

// ── 写操作 ────────────────────────────────
always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        reg_ctrl <= 'd0;
        reg_data <= 'd0;
    end else if (write_en) begin
        case (PADDR[3:2])
            2'h0: reg_ctrl <= PWDATA;  // 写 0x00
            2'h1: ;                    // 0x04 只读，忽略写
            2'h2: reg_data <= PWDATA;  // 写 0x08
            default: ;
        endcase
    end
end

// ── 读操作（组合逻辑） ─────────────────────
always @(*) begin
    PRDATA = 'd0;
    if (read_en) begin
        case (PADDR[3:2])
            2'h0: PRDATA = reg_ctrl;
            2'h1: PRDATA = reg_stat;
            2'h2: PRDATA = reg_data;
            default: PRDATA = 'd0;
        endcase
    end
end

endmodule
```

---

## 八、APB 与 AHB 对比

### 传输周期对比

```
AHB（流水线，最快1周期）:

  T1        T2        T3        T4
  ┌─────────┬─────────┬─────────┬─────────┐
  │ ADDR(1) │ DATA(1) │ DATA(2) │ DATA(3) │
  │         │ ADDR(2) │ ADDR(3) │         │
  └─────────┴─────────┴─────────┴─────────┘
  地址与数据重叠，流水线传输

APB（非流水线，最少2周期）:

  T1        T2        T3        T4        T5
  ┌─────────┬─────────┬─────────┬─────────┐
  │  IDLE   │  SETUP  │ ACCESS  │  SETUP  │ ACCESS
  │         │ ADDR(1) │ DATA(1) │ ADDR(2) │ DATA(2)
  └─────────┴─────────┴─────────┴─────────┘
  每次传输独立，不重叠
```

### 特性对比

| 特性 | AHB | APB |
|------|:---:|:---:|
| 最小传输周期 | 1 | **2** |
| 流水线支持 | ✅ | ❌ |
| 多主机支持 | ✅（含仲裁器）| ❌（仅桥接器） |
| 突发传输 | ✅ | ❌ |
| 逻辑复杂度 | 高 | **低** |
| 功耗 | 较高 | **低** |
| 适用场景 | Cache / RAM | **UART / GPIO / I2C** |

---

## 九、学习路线

```
Step 1: 手写 APB Slave（纯寄存器读写）     ← 从这里开始
         │
         ▼
Step 2: APB Slave + 中断逻辑
         │
         ▼
Step 3: APB Master（发起读写请求）
         │
         ▼
Step 4: AHB-to-APB Bridge（桥接器）        ← 面试加分
         │
         ▼
Step 5: 完整 APB 总线系统仿真（1主3从）
```

---

## 十、面试高频问题

| 问题 | 关键答案 |
|------|----------|
| APB 最少几个周期传输？ | **2个**（SETUP + ACCESS） |
| PENABLE 什么时候拉高？ | **SETUP 后的第一个上升沿**（ACCESS 阶段开始时） |
| PREADY=0 的作用？ | **在 ACCESS 阶段插入等待周期**，Slave 未准备好时使用 |
| 如何判断写操作有效？ | **PSEL && PENABLE && PWRITE 同时为高** |
| APB 和 AHB 最大区别？ | **APB 无流水线、无多主机、最少2周期** |
| PSLVERR 什么时候有效？ | **ACCESS 阶段 PREADY=1 同时 PSLVERR=1** |
| PSTRB 的作用？ | **字节选通，4位对应32位数据的4个字节** |

---

## 参考资料

- **ARM IHI0024C**: AMBA APB Protocol Specification（官方文档，30页，必读）
- **ARM IHI0011A**: AMBA AHB Protocol Specification（对比学习）

---

*Created: 2026-02 | 协议版本: APB3 | 下一步: `17. apb/apb_slave.v`*
