//=============================================================================
// dma_pkg.sv —— DMA 控制器共享包
//
// 内容：错误码枚举、寄存器偏移、CTRL/STATUS 位域、AXI 响应码常量。
// 被 dma_regs / dma_ctrl / testbench 共同引用，位域定义以此文件为唯一基准。
//=============================================================================
package dma_pkg;

  // ---------------------------------------------------------------------------
  // 错误码（STATUS.ERRCODE 字段，dma_ctrl 错误态写入）
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    ERR_NONE  = 2'd0,  // 无错误
    ERR_SLV   = 2'd1,  // slave 返回 SLVERR
    ERR_DEC   = 2'd2,  // decode 错误（地址未命中）
    ERR_RRESP = 2'd3   // 读通道 rresp 错误
  } errcode_e;

  // ---------------------------------------------------------------------------
  // 寄存器偏移（AXI4-Lite 字节偏移，地址空间 0x00 ~ 0x14）
  // ---------------------------------------------------------------------------
  localparam logic [5:0] REG_SRC    = 6'h00;  // 源起始地址        RW
  localparam logic [5:0] REG_DST    = 6'h04;  // 目的起始地址      RW
  localparam logic [5:0] REG_LEN    = 6'h08;  // 传输长度（word）  RW
  localparam logic [5:0] REG_CTRL   = 6'h0C;  // 控制寄存器        RW
  localparam logic [5:0] REG_STATUS = 6'h10;  // 状态寄存器        RO
  localparam logic [5:0] REG_ICR    = 6'h14;  // 中断清除          WO（读 0）

  // CTRL 寄存器位域
  localparam int CTRL_EN        = 0;  // [0]   全局使能
  localparam int CTRL_START     = 1;  // [1]   写 1 触发传输，硬件 1~2 拍自清
  localparam int CTRL_BURST_LSB = 2;  // [4:2] BURST 字段最低位（log2 beats）
  localparam int CTRL_BURST_W   = 3;  //       BURST 字段宽度（0=SINGLE..4=16）
  localparam int CTRL_IE_TC     = 8;  // [8]   TC 中断使能
  localparam int CTRL_IE_TE     = 9;  // [9]   TE 中断使能

  // STATUS 寄存器位域
  localparam int ST_BUSY    = 0;  // [0]   传输进行中
  localparam int ST_DONE    = 1;  // [1]   传输完成
  localparam int ST_ERR_LSB = 4;  // [5:4] ERRCODE 字段最低位
  localparam int ST_ERR_W   = 2;  //       ERRCODE 字段宽度

  // AXI4-Lite 响应码
  localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

endpackage : dma_pkg
