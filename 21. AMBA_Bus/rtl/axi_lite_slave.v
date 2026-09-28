`timescale 1ns / 1ps
//============================================================================
// axi_lite_slave.v —— AXI4-Lite 从机（面试可默写版）
//
// 设计要点（对照 AXI 规范 IHI 0022）：
//   1. 五通道各自独立握手：AWREADY / WREADY / BVALID / ARREADY / RVALID
//      互不依赖对方 VALID —— 避免组合环与死锁
//   2. 握手铁律：本模块 READY 永不依赖对方 VALID（AWREADY = ~aw_pend & ~b_valid），
//      VALID 由 master 驱动，一旦拉高保持到握手完成（TB 验证 BVALID/RVALID 保持）
//   3. AW / W 双顺序处理：谁先到都行，各自锁存 + pending 标志，
//      两个都到齐才执行写并回 B —— 面试必考
//   4. WSTRB 逐字节写使能（AXI-Lite 规范建议全 1，但从机应兼容子集）
//   5. 越界地址回 SLVERR（读回 RRESP=SLVERR + 数据 0）
//   6. 无 X 态、可综合
//
// 寄存器映射（与 ahb_lite_slave 保持同构，方便对照学习）：
//   0x00 CTRL  RW  控制寄存器
//   0x04 STAT  RO  状态寄存器（bit0: DATA0 非零, bit1: DATA1 非零）
//   0x08 DATA0 RW  数据寄存器 0
//   0x0C DATA1 RW  数据寄存器 1
//   其余      ——  越界，回 SLVERR
//
// 仿真：iverilog -g2012 -o sim/axi_lite_slave_sim.vvp rtl/axi_lite_slave.v
//           sim/axi_lite_slave_tb.v && vvp sim/axi_lite_slave_sim.vvp
//============================================================================
module axi_lite_slave #(
    parameter ADDR_WIDTH = 12                  // 从机地址空间 2^12 = 4KB
)(
    input  wire                  ACLK,
    input  wire                  ARESETn,      // 低有效同步/异步复位均可，本模块用异步

    // AXI4-Lite 写地址通道 AW
    input  wire [ADDR_WIDTH-1:0] AWADDR,
    input  wire [2:0]            AWPROT,       // 协议完整性保留，本模块不检查
    input  wire                  AWVALID,
    output wire                  AWREADY,

    // AXI4-Lite 写数据通道 W
    input  wire [31:0]           WDATA,
    input  wire [3:0]            WSTRB,
    input  wire                  WVALID,
    output wire                  WREADY,

    // AXI4-Lite 写响应通道 B
    output wire [1:0]            BRESP,        // 00 OKAY / 10 SLVERR
    output wire                  BVALID,
    input  wire                  BREADY,

    // AXI4-Lite 读地址通道 AR
    input  wire [ADDR_WIDTH-1:0] ARADDR,
    input  wire [2:0]            ARPROT,
    input  wire                  ARVALID,
    output wire                  ARREADY,

    // AXI4-Lite 读数据通道 R
    output wire [31:0]           RDATA,
    output wire [1:0]            RRESP,        // 00 OKAY / 10 SLVERR
    output wire                  RVALID,
    input  wire                  RREADY
);

    localparam [1:0] RESP_OKAY   = 2'b00,
                     RESP_SLVERR = 2'b10;

    //----------------------------------------------------------------------
    // 1. 地址合法性判断（组合，握手时锁存）
    //    AXI-Lite 要求字对齐；对齐且落在 0x00~0x0C 窗口内才合法
    //----------------------------------------------------------------------
    wire aw_err = (AWADDR[1:0] != 2'b00) | |AWADDR[ADDR_WIDTH-1:4];
    wire ar_err = (ARADDR[1:0] != 2'b00) | |ARADDR[ADDR_WIDTH-1:4];

    //----------------------------------------------------------------------
    // 2. 写通道：AW / W 双顺序处理
    //    aw_pend=1 表示已收 AW 等待 W；w_pend=1 表示已收 W 等待 AW；
    //    两者都为 1 且 B 通道空闲 → 本拍执行写、下一拍起 BVALID=1
    //----------------------------------------------------------------------
    reg                  aw_pend, w_pend;
    reg [ADDR_WIDTH-1:0] awaddr_q;
    reg                  aw_err_q;
    reg [31:0]           wdata_q;
    reg [3:0]            wstrb_q;
    reg                  b_valid;
    reg [1:0]            bresp_q;

    // READY 只看自己的缓冲状态，绝不看对方 VALID（握手铁律）
    assign AWREADY = ~aw_pend & ~b_valid;
    assign WREADY  = ~w_pend  & ~b_valid;

    wire aw_fire = AWVALID & AWREADY;
    wire w_fire  = WVALID  & WREADY;
    wire b_fire  = b_valid & BREADY;
    wire wr_commit = aw_pend & w_pend & ~b_valid;   // AW 和 W 都到齐，写提交

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            aw_pend  <= 1'b0;
            w_pend   <= 1'b0;
            b_valid  <= 1'b0;
            bresp_q  <= RESP_OKAY;
            awaddr_q <= {ADDR_WIDTH{1'b0}};
            aw_err_q <= 1'b0;
            wdata_q  <= 32'h0;
            wstrb_q  <= 4'h0;
        end else begin
            if (aw_fire) begin                       // 收到 AW：锁存地址，等 W
                aw_pend  <= 1'b1;
                awaddr_q <= AWADDR;
                aw_err_q <= aw_err;
            end
            if (w_fire) begin                        // 收到 W：锁存数据，等 AW
                w_pend  <= 1'b1;
                wdata_q <= WDATA;
                wstrb_q <= WSTRB;
            end
            if (wr_commit) begin                     // 写提交 + 产生 B 响应
                aw_pend <= 1'b0;
                w_pend  <= 1'b0;
                b_valid <= 1'b1;
                bresp_q <= aw_err_q ? RESP_SLVERR : RESP_OKAY;
            end else if (b_fire)                     // BVALID 保持到 BREADY 才清
                b_valid <= 1'b0;
        end
    end

    //----------------------------------------------------------------------
    // 3. 寄存器堆：在 wr_commit 拍提交写（wstrb_q 逐字节选通）
    //----------------------------------------------------------------------
    reg [31:0] ctrl_q, data0_q, data1_q;

    integer i;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            ctrl_q  <= 32'h0;
            data0_q <= 32'h0;
            data1_q <= 32'h0;
        end else if (wr_commit && !aw_err_q) begin
            case (awaddr_q[3:2])
                2'd0: for (i = 0; i < 4; i = i + 1)          // 0x00 CTRL
                          if (wstrb_q[i]) ctrl_q [8*i +: 8] <= wdata_q[8*i +: 8];
                2'd2: for (i = 0; i < 4; i = i + 1)          // 0x08 DATA0
                          if (wstrb_q[i]) data0_q[8*i +: 8] <= wdata_q[8*i +: 8];
                2'd3: for (i = 0; i < 4; i = i + 1)          // 0x0C DATA1
                          if (wstrb_q[i]) data1_q[8*i +: 8] <= wdata_q[8*i +: 8];
                default: ;                                  // 0x04 STAT 只读，忽略
            endcase
        end
    end

    //----------------------------------------------------------------------
    // 4. 读通道：AR 握手锁存地址 → 下一拍 RVALID=1 → 保持到 RREADY
    //----------------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] araddr_q;
    reg                  ar_err_q;
    reg                  r_valid;

    assign ARREADY = ~r_valid;                       // R 通道空闲才能接新读请求

    wire ar_fire = ARVALID & ARREADY;
    wire r_fire  = r_valid & RREADY;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            r_valid <= 1'b0;
            araddr_q<= {ADDR_WIDTH{1'b0}};
            ar_err_q<= 1'b0;
        end else begin
            if (ar_fire) begin                       // 收到读请求
                r_valid <= 1'b1;
                araddr_q<= ARADDR;
                ar_err_q<= ar_err;
            end else if (r_fire)                     // RVALID 保持到 RREADY
                r_valid <= 1'b0;
        end
    end

    //----------------------------------------------------------------------
    // 5. 读数据多路 + 输出
    //----------------------------------------------------------------------
    wire [31:0] stat_q = {30'd0, |data0_q, |data1_q};

    reg [31:0] rdata_mux;

    always @(*) begin
        case (araddr_q[3:2])
            2'd0:    rdata_mux = ctrl_q;
            2'd1:    rdata_mux = stat_q;
            2'd2:    rdata_mux = data0_q;
            default: rdata_mux = data1_q;
        endcase
    end

    assign RVALID = r_valid;
    assign RRESP  = ar_err_q ? RESP_SLVERR : RESP_OKAY;
    assign RDATA  = ar_err_q ? 32'h0        : rdata_mux;

    assign BRESP  = bresp_q;
    assign BVALID = b_valid;

endmodule
