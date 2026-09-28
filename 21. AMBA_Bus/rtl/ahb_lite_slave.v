`timescale 1ns / 1ps
//============================================================================
// ahb_lite_slave.v —— 最小 AHB-Lite 从机（面试可默写版）
//
// 设计要点（对齐 cnn_ram 的 cmsdk_ahb_eg_slave_interface.v 风格并简化）：
//   1. 两相位流水线：地址相位采样打一拍，与数据相位的 HWDATA 对齐
//   2. HTRANS[1] 检查：只有 NONSEQ(10)/SEQ(11) 才是有效传输，
//      IDLE(00)/BUSY(01) 一律忽略（BUSY 是 burst 中途暂停，从机必须 OKAY 直通）
//   3. HSIZE + 地址低位生成 byte-lane，支持 byte/halfword/word 写
//   4. HREADYOUT 插等待（SLOW 寄存器固定插 1 拍，模拟慢速外设）
//   5. 越界地址回 ERROR（两拍扩展响应，IHI 0033：第 1 拍 HRESP=1+HREADYOUT=0，
//      第 2 拍 HRESP=1+HREADYOUT=1）
//   6. HRDATA 组合输出（面积小；若时序紧可在 ap_addr 后再打一拍寄存输出，
//      代价是读数据相位必须插 1 拍等待——面试常问的取舍）
//
// 寄存器映射（ADDR_WIDTH 低位译码，默认 4KB 空间）：
//   0x00 CTRL  RW  控制寄存器
//   0x04 STAT  RO  状态寄存器（bit0: DATA0 非零, bit1: DATA1 非零）
//   0x08 DATA0 RW  数据寄存器 0
//   0x0C DATA1 RW  数据寄存器 1
//   0x10 SLOW RW  慢速寄存器（访问固定插 1 拍等待）
//   其余      ——  越界，回 ERROR
//
// 仿真：iverilog -g2012 -o sim/ahb_lite_slave_sim.vvp rtl/ahb_lite_slave.v
//           sim/ahb_lite_slave_tb.v && vvp sim/ahb_lite_slave_sim.vvp
//============================================================================
module ahb_lite_slave #(
    parameter ADDR_WIDTH = 12                  // 从机地址空间 2^12 = 4KB
)(
    input  wire                  HCLK,
    input  wire                  HRESETn,

    // AHB-Lite 从机接口
    input  wire                  HSEL,         // 从机选择（地址译码器输出）
    input  wire [ADDR_WIDTH-1:0] HADDR,        // 地址（地址相位有效）
    input  wire [1:0]            HTRANS,       // 00 IDLE / 01 BUSY / 10 NONSEQ / 11 SEQ
    input  wire [2:0]            HSIZE,        // 000 byte / 001 halfword / 010 word
    input  wire                  HWRITE,       // 地址相位有效
    input  wire [31:0]           HWDATA,       // 写数据（数据相位有效）
    input  wire                  HREADY,       // 总线级就绪（矩阵回传；低电平冻结流水线）
    output wire [31:0]           HRDATA,       // 读数据（数据相位有效）
    output wire                  HREADYOUT,    // 本从机就绪输出
    output wire                  HRESP         // 0 = OKAY, 1 = ERROR
);

    //----------------------------------------------------------------------
    // 1. 地址译码（组合）：只看本从机窗口内的低位地址
    //    用「字索引 HADDR[4:2]」判定：byte/halfword 访问（地址低位非 0）合法，
    //    归属其所在字对应的寄存器 —— 与 byte-lane 生成配合
    //----------------------------------------------------------------------
    wire ap_xfer = HSEL & HTRANS[1];           // 本拍地址相位有有效传输
    wire addr_in_win  = ~|HADDR[ADDR_WIDTH-1:5];          // 32B 窗口内
    wire addr_is_reg  = addr_in_win & (HADDR[4:2] < 3'd4);// 字 0~3：0x00/04/08/0C
    wire addr_is_slow = addr_in_win & (HADDR[4:2] == 3'd4);// 字 4：0x10 SLOW
    wire addr_slow    = ap_xfer & addr_is_slow;
    wire addr_err     = ap_xfer & ~(addr_is_reg | addr_is_slow);

    //----------------------------------------------------------------------
    // 2. 地址相位采样：HREADY 为高（总线在前进）时把地址相位信息打一拍，
    //    使地址与数据相位的 HWDATA 同拍出现；HREADY 为低时保持（流水线冻结）
    //----------------------------------------------------------------------
    reg                  ap_valid;
    reg [ADDR_WIDTH-1:0] ap_addr;
    reg                  ap_write;
    reg [2:0]            ap_size;
    reg                  ap_err;
    reg                  ap_slow;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            ap_valid <= 1'b0;
            ap_addr  <= {ADDR_WIDTH{1'b0}};
            ap_write <= 1'b0;
            ap_size  <= 3'd0;
            ap_err   <= 1'b0;
            ap_slow  <= 1'b0;
        end else if (HREADY) begin
            ap_valid <= ap_xfer;
            ap_addr  <= HADDR;
            ap_write <= HWRITE;
            ap_size  <= HSIZE;
            ap_err   <= addr_err;
            ap_slow  <= addr_slow;
        end
    end

    //----------------------------------------------------------------------
    // 3. 数据相位状态机：OKAY 直通 / WAIT 插 1 拍 / ERROR 两拍扩展
    //----------------------------------------------------------------------
    localparam [1:0] DP_OKAY = 2'd0,           // 零等待直通
                     DP_WAIT = 2'd1,           // SLOW 寄存器等待
                     DP_ERR1 = 2'd2,           // ERROR 第 1 拍（HREADYOUT=0）
                     DP_ERR2 = 2'd3;           // ERROR 第 2 拍（完成）

    reg [1:0] dp_state;

    // 本从机当前数据相位完成 + 总线前进（单从机回环时 HREADY 就是 HREADYOUT）
    wire dp_done = HREADY & HREADYOUT;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            dp_state <= DP_OKAY;
        else begin
            case (dp_state)
                // 总线前进时接收新的数据相位（由本沿正在采样的地址相位决定）
                DP_OKAY: if (HREADY)
                             dp_state <= ap_xfer ? (addr_err  ? DP_ERR1 :
                                                    addr_slow ? DP_WAIT : DP_OKAY)
                                                 : DP_OKAY;
                DP_WAIT: dp_state <= DP_OKAY;          // 等 1 拍后无条件完成
                DP_ERR1: dp_state <= DP_ERR2;          // ERROR 第 1 拍结束
                DP_ERR2: if (dp_done)                  // ERROR 完成沿，同时衔接下一笔
                             dp_state <= ap_xfer ? (addr_err  ? DP_ERR1 :
                                                    addr_slow ? DP_WAIT : DP_OKAY)
                                                 : DP_OKAY;
                default: dp_state <= DP_OKAY;
            endcase
        end
    end

    assign HREADYOUT = (dp_state == DP_WAIT) || (dp_state == DP_ERR1) ? 1'b0 : 1'b1;
    assign HRESP     = (dp_state == DP_ERR1) || (dp_state == DP_ERR2);

    //----------------------------------------------------------------------
    // 4. byte-lane 生成：HSIZE + 地址低位 → 逐字节写使能（面试高频考点）
    //----------------------------------------------------------------------
    wire [1:0] ap_offset = ap_addr[1:0];
    reg  [3:0] byte_lane;

    always @(*) begin
        case (ap_size[1:0])
            2'b00: case (ap_offset)                     // byte：选中 1 字节
                2'b00:   byte_lane = 4'b0001;
                2'b01:   byte_lane = 4'b0010;
                2'b10:   byte_lane = 4'b0100;
                default: byte_lane = 4'b1000;
            endcase
            2'b01:   byte_lane = ap_offset[1] ? 4'b1100 : 4'b0011; // halfword
            default: byte_lane = 4'b1111;               // word
        endcase
    end

    //----------------------------------------------------------------------
    // 5. 寄存器堆：写在数据相位完成沿提交（此时 HWDATA 稳定有效）
    //----------------------------------------------------------------------
    reg [31:0] ctrl_q, data0_q, data1_q, slow_q;

    wire wr_fire = dp_done & ap_valid & ap_write & ~ap_err;

    integer i;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            ctrl_q  <= 32'h0;
            data0_q <= 32'h0;
            data1_q <= 32'h0;
            slow_q  <= 32'h0;
        end else if (wr_fire) begin
            case (ap_addr[4:2])
                3'd0: for (i = 0; i < 4; i = i + 1)          // 0x00 CTRL
                          if (byte_lane[i]) ctrl_q [8*i +: 8] <= HWDATA[8*i +: 8];
                3'd2: for (i = 0; i < 4; i = i + 1)          // 0x08 DATA0
                          if (byte_lane[i]) data0_q[8*i +: 8] <= HWDATA[8*i +: 8];
                3'd3: for (i = 0; i < 4; i = i + 1)          // 0x0C DATA1
                          if (byte_lane[i]) data1_q[8*i +: 8] <= HWDATA[8*i +: 8];
                3'd4: for (i = 0; i < 4; i = i + 1)          // 0x10 SLOW
                          if (byte_lane[i]) slow_q [8*i +: 8] <= HWDATA[8*i +: 8];
                default: ;                         // 0x04 STAT 只读，写被忽略
            endcase
        end
    end

    //----------------------------------------------------------------------
    // 6. 读多路选择：HRDATA 在数据相位组合输出
    //----------------------------------------------------------------------
    wire [31:0] stat_q = {30'd0, |data0_q, |data1_q};    // STAT 实时状态位

    reg [31:0] rdata_mux;

    always @(*) begin
        case (ap_addr[4:2])
            3'd0:    rdata_mux = ctrl_q;
            3'd1:    rdata_mux = stat_q;
            3'd2:    rdata_mux = data0_q;
            3'd3:    rdata_mux = data1_q;
            3'd4:    rdata_mux = slow_q;
            default: rdata_mux = 32'h0;
        endcase
    end

    assign HRDATA = (ap_valid & ~ap_err) ? rdata_mux : 32'h0;

endmodule
