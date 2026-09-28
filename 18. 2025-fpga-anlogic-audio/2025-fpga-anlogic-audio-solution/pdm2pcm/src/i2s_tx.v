`timescale 1ns / 1ps
// 模块: i2s_tx
// 说明: I2S 发送模块，从异步 DAC FIFO 读取并按 I2S 时序输出到 DAC（串行数据）。
// 主要端口:
//  - rst_n: 复位信号，低电平有效
//  - dacfifo_wrclk/dacfifo_wren/dacfifo_wrdata: DAC FIFO 写接口（系统 clk 域写数据）
//  - dacfifo_full: FIFO 满标志
//  - bclk: I2S 位时钟
//  - daclrc: I2S 左右声道帧时钟（LRCK）
//  - dacdat: I2S 串行数据输出（连接到 ES8388 的 DAC 输入）
// 说明/备注:
//  - 在 bclk 域中按 DATA_WIDTH 将并行数据串行化并输出，支持左右声道切换。
// -----------------------------------------------------------------------------
module i2s_tx
#(
    parameter DATA_WIDTH        = 32     //left+right = 16 +16 =32 
)
(
    input rst_n,
    input dacfifo_wrclk,    // DAC FIFO 写时钟信号（系统域，用于写入数据）
    input dacfifo_wren,     // DAC FIFO 写使能信号（高电平时写入 wrdata）
    input [DATA_WIDTH - 1 : 0] dacfifo_wrdata,  // DAC FIFO 写数据
    output dacfifo_full,    // DAC FIFO 满标志

    input  bclk,
    input  daclrc,     // DAC LRCK（左右声道时钟）
    output reg dacdat
);

localparam state_idle = 2'd0;  // 空闲状态
localparam state_tx_left_data = 2'd1;  // 发送左声道数据
localparam state_tx_right_data = 2'd2; // 发送右声道数据

reg[1:0] state; 
wire dacfifo_empty;
wire dacfifo_rden;
wire [DATA_WIDTH - 1 : 0] dacfifo_rddata;
reg [DATA_WIDTH - 1 : 0] dacfifo_rddata_r0;
reg daclrc_r0;
reg daclrc_nege;
reg daclrc_pose;
reg [7:0] bit_cnt;      // 位计数

assign dacfifo_rden = (~dacfifo_empty && daclrc_nege) ? 1'd1 : 1'd0;          // 当 LRCK 下降沿且 FIFO 非空时自动读出
always@(posedge bclk) begin
    daclrc_r0 <= daclrc;
end

always@(posedge bclk or negedge rst_n)
if(~rst_n) begin
	daclrc_pose <= 1'd0;
	daclrc_nege <= 1'd0;
end
else begin
	daclrc_pose <= daclrc & (!daclrc_r0);
	daclrc_nege <= (!daclrc) & daclrc_r0;
end

always@(negedge daclrc)
    dacfifo_rddata_r0 <= dacfifo_rddata;


always@(negedge bclk or negedge rst_n)
if(~rst_n)
begin
    state <= state_idle;
    bit_cnt <= 8'd0;
    dacdat <= 1'd0;
end
else
begin
    case(state)
        state_idle:
        begin
            bit_cnt <= DATA_WIDTH - 1'd1;
            dacdat <= 1'd0;
            if(daclrc_nege)        // 检测到 LRCK 下降沿，开始左声道发送
            begin
                state <= state_tx_left_data;
                bit_cnt <= bit_cnt - 1'd1;
                dacdat <= dacfifo_rddata_r0[bit_cnt]; 
            end
        end

        state_tx_left_data:
        begin
            if(bit_cnt == DATA_WIDTH/2 - 1'd1)
            begin
                dacdat <= 1'd0;
                if(daclrc_pose) begin
                    state <= state_tx_right_data;
                    bit_cnt <= bit_cnt - 1'd1;
                    dacdat <= dacfifo_rddata_r0[bit_cnt];
                end
            end
            else
            begin
                bit_cnt <= bit_cnt - 1'd1;
                dacdat <= dacfifo_rddata_r0[bit_cnt];  
            end
        end

        state_tx_right_data:
        begin
            if(bit_cnt == 0)
            begin
                state <= state_idle;
                bit_cnt <= bit_cnt - 1'd1;
                dacdat <= dacfifo_rddata_r0[bit_cnt];
            end
            else
            begin
                bit_cnt <= bit_cnt - 1'd1;
                dacdat <= dacfifo_rddata_r0[bit_cnt];
            end
        end
    endcase
end


async_fifo #(
	.DATA_WIDTH(DATA_WIDTH),
	.ADDR_WIDTH(8),
	.FULL_AHEAD(1),
	.SHOWAHEAD_EN(0)
)dac_fifo
(
	.reset(~rst_n),
	//fifo wr
	.wrclk(dacfifo_wrclk),
	.wren(dacfifo_wren),
	.wrdata(dacfifo_wrdata),
	.full(dacfifo_full),
	.almost_full(),
	.wrusedw(),
	//fifo rd
	.rdclk(bclk),
	.rden(dacfifo_rden),
	.rddata(dacfifo_rddata),
	.empty(dacfifo_empty),
	.rdusedw()
);
//fifo_tx fifo_tx (
//  .rst(~rst_n),                  // input wire rst
//  .wr_clk(dacfifo_wrclk),            // input wire wr_clk
//  .rd_clk(bclk),            // input wire rd_clk
//  .din(dacfifo_wrdata),                  // input wire [31 : 0] din
//  .wr_en(dacfifo_wren),              // input wire wr_en
//  .rd_en(dacfifo_rden),              // input wire rd_en
//  .dout(dacfifo_rddata),                // output wire [31 : 0] dout
//  .full(dacfifo_full),                // output wire full
//  .empty(dacfifo_empty),              // output wire empty
//  .wr_rst_busy(),  // output wire wr_rst_busy
//  .rd_rst_busy()  // output wire rd_rst_busy
//);

endmodule