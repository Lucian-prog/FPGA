`timescale 1ns / 1ps
// 模块: apb_slave
// 说明: APB3 协议从机，内含4个32位寄存器
//       - 0x00: REG_CTRL  控制寄存器  (R/W)
//       - 0x04: REG_STAT  状态寄存器  (R，写忽略)
//       - 0x08: REG_DATA0 数据寄存器0 (R/W)
//       - 0x0C: REG_DATA1 数据寄存器1 (R/W)
//       支持 PSTRB 字节选通写、PSLVERR 地址越界错误响应
// 参考: AMBA APB Protocol Specification ARM IHI0024C

module apb_slave #(
  parameter DATA_WIDTH = 32,        // 数据位宽（固定32）
  parameter ADDR_WIDTH = 8          // 地址位宽
)(
  // ── APB3 接口 ──────────────────────────────────────────
  input                         PCLK,     // 总线时钟
  input                         PRESETn,  // 低有效异步复位
  input  [ADDR_WIDTH-1:0]       PADDR,    // 地址总线
  input                         PSEL,     // 从机片选
  input                         PENABLE,  // 访问使能（第2周期拉高）
  input                         PWRITE,   // 1=写，0=读
  input  [DATA_WIDTH-1:0]       PWDATA,   // 写数据
  input  [DATA_WIDTH/8-1:0]     PSTRB,    // 字节选通（APB3）
  output reg [DATA_WIDTH-1:0]   PRDATA,   // 读数据
  output                        PREADY,   // 从机就绪（本设计恒为1）
  output reg                    PSLVERR   // 从机错误（地址越界时拉高）
);

  // ── 内部寄存器定义 ──────────────────────────────────────
  reg [DATA_WIDTH-1:0] reg_ctrl;   // 0x00 控制寄存器 (R/W)
  reg [DATA_WIDTH-1:0] reg_stat;   // 0x04 状态寄存器 (R)
  reg [DATA_WIDTH-1:0] reg_data0;  // 0x08 数据寄存器0 (R/W)
  reg [DATA_WIDTH-1:0] reg_data1;  // 0x0C 数据寄存器1 (R/W)

  // ── 地址偏移常量（字节地址，低2位恒为00） ─────────────
  localparam ADDR_CTRL  = 8'h00;
  localparam ADDR_STAT  = 8'h04;
  localparam ADDR_DATA0 = 8'h08;
  localparam ADDR_DATA1 = 8'h0C;

  // ── ACCESS 阶段有效信号 ────────────────────────────────
  // PSEL=1 且 PENABLE=1 时才是有效的传输访问阶段
  wire access_valid = PSEL & PENABLE;
  wire write_valid  = access_valid &  PWRITE;
  wire read_valid   = access_valid & ~PWRITE;

  // ── 地址越界检测 ───────────────────────────────────────
  wire addr_valid = (PADDR == ADDR_CTRL ) |
                    (PADDR == ADDR_STAT ) |
                    (PADDR == ADDR_DATA0) |
                    (PADDR == ADDR_DATA1);

  // ── PREADY / PSLVERR 输出 ─────────────────────────────
  // 本设计无需等待周期，PREADY 恒为1
  assign PREADY = 1'b1;

  // PSLVERR 必须与 PREADY=1 同周期有效，且仅在 ACCESS 阶段
  // 地址越界时报错
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
      PSLVERR <= 1'b0;
    else if (access_valid)
      PSLVERR <= ~addr_valid;   // 地址不合法则报错
    else
      PSLVERR <= 1'b0;
  end

  // ── 写操作（时序逻辑，支持 PSTRB 字节选通） ───────────
  // PSTRB[n]=1 表示 PWDATA[8n+7:8n] 字节有效
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      reg_ctrl  <= {DATA_WIDTH{1'b0}};
      reg_data0 <= {DATA_WIDTH{1'b0}};
      reg_data1 <= {DATA_WIDTH{1'b0}};
    end else if (write_valid && addr_valid) begin
      case (PADDR)
        ADDR_CTRL: begin
          // 按字节选通写入
          if (PSTRB[0]) reg_ctrl[ 7: 0] <= PWDATA[ 7: 0];
          if (PSTRB[1]) reg_ctrl[15: 8] <= PWDATA[15: 8];
          if (PSTRB[2]) reg_ctrl[23:16] <= PWDATA[23:16];
          if (PSTRB[3]) reg_ctrl[31:24] <= PWDATA[31:24];
        end
        ADDR_STAT: ; // 只读，写操作静默忽略
        ADDR_DATA0: begin
          if (PSTRB[0]) reg_data0[ 7: 0] <= PWDATA[ 7: 0];
          if (PSTRB[1]) reg_data0[15: 8] <= PWDATA[15: 8];
          if (PSTRB[2]) reg_data0[23:16] <= PWDATA[23:16];
          if (PSTRB[3]) reg_data0[31:24] <= PWDATA[31:24];
        end
        ADDR_DATA1: begin
          if (PSTRB[0]) reg_data1[ 7: 0] <= PWDATA[ 7: 0];
          if (PSTRB[1]) reg_data1[15: 8] <= PWDATA[15: 8];
          if (PSTRB[2]) reg_data1[23:16] <= PWDATA[23:16];
          if (PSTRB[3]) reg_data1[31:24] <= PWDATA[31:24];
        end
        default: ;
      endcase
    end
  end

  // ── 状态寄存器内部更新（示例逻辑） ────────────────────
  // reg_stat[0]: 数据寄存器0非零标志
  // reg_stat[1]: 数据寄存器1非零标志
  // 实际项目中可挂接功能逻辑
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
      reg_stat <= {DATA_WIDTH{1'b0}};
    else begin
      reg_stat[0] <= |reg_data0;  // DATA0 非零
      reg_stat[1] <= |reg_data1;  // DATA1 非零
      reg_stat[DATA_WIDTH-1:2] <= {(DATA_WIDTH-2){1'b0}};
    end
  end

  // ── 读操作（组合逻辑，在 ACCESS 阶段同步输出） ────────
  always @(*) begin
    PRDATA = {DATA_WIDTH{1'b0}};
    if (read_valid) begin
      case (PADDR)
        ADDR_CTRL:  PRDATA = reg_ctrl;
        ADDR_STAT:  PRDATA = reg_stat;
        ADDR_DATA0: PRDATA = reg_data0;
        ADDR_DATA1: PRDATA = reg_data1;
        default:    PRDATA = {DATA_WIDTH{1'b0}};
      endcase
    end
  end

endmodule
