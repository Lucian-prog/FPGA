`timescale 1ns / 1ps
// 模块: async_fifo
// 说明: 异步 FIFO 顶层封装，包含控制逻辑与双口 RAM，用于跨时钟域安全传输数据。
// 主要参数:
//  - DATA_WIDTH: 数据宽度
//  - ADDR_WIDTH: 地址宽度（决定 FIFO 深度）
//  - FULL_AHEAD / SHOWAHEAD_EN: FIFO 行为配置
// 主要端口:
//  - reset: 异步复位（高电平有效）
//  - wrclk/wren/wrdata: 写端口（写时钟域）
//  - rdclk/rden/rddata: 读端口（读时钟域）
//  - full/empty/wrusedw/rdusedw: 状态指示
// 说明/备注:
//  - 使用 `async_fifo_ctrl` 负责读写指针同步和状态生成，底层使用 `dpram` 实现存储。
// -----------------------------------------------------------------------------
module async_fifo #(
  parameter DATA_WIDTH   = 16,
  parameter ADDR_WIDTH   = 16,
  parameter FULL_AHEAD   = 1,
  parameter SHOWAHEAD_EN = 0
)
(
  input                    reset,
  //fifo wr
  input                    wrclk,
  input                    wren,
  input   [DATA_WIDTH-1:0] wrdata,
  output                   full,
  output                   almost_full,
  output  [ADDR_WIDTH:0]   wrusedw,
  //fifo rd
  input                    rdclk,
  input                    rden,
  output  [DATA_WIDTH-1:0] rddata,
  output                   empty,
  output  [ADDR_WIDTH:0]   rdusedw
);

wire  [DATA_WIDTH-1:0] ram_dout;
wire  [ADDR_WIDTH-1:0] ram_wraddr;
wire  [ADDR_WIDTH-1:0] ram_rdaddr;
wire  [DATA_WIDTH-1:0] ram_din;
wire                   ram_wren;

wire  [DATA_WIDTH-1:0] rddata_tmp;
reg   [DATA_WIDTH-1:0] rddata_tmp_latch;

always@(posedge rdclk or posedge reset)
  if(reset)
    rddata_tmp_latch <= 'd0;
  else if(rden)
    rddata_tmp_latch <= rddata_tmp;

generate
  if(SHOWAHEAD_EN) begin: inst0
  //
    assign rddata = rddata_tmp;
  //
  end
  else begin: inst1
  //
    assign rddata = rddata_tmp_latch;
  //
  end
endgenerate

async_fifo_ctrl #(
  .DATA_WIDTH (DATA_WIDTH ),
  .ADDR_WIDTH (ADDR_WIDTH ),
  .FULL_AHEAD (FULL_AHEAD )
)async_fifo_ctrl_inst
(
  .reset       (reset       ),
  //fifo wr
  .wrclk       (wrclk       ),
  .wren        (wren        ),
  .wrdata      (wrdata      ),
  .full        (full        ),
  .almost_full (almost_full ),
  .wrusedw     (wrusedw     ),
  //fifo rd
  .rdclk       (rdclk       ),
  .rden        (rden        ),
  .rddata      (rddata_tmp  ),
  .empty       (empty       ),
  .rdusedw     (rdusedw     ),
  //ram
  .ram_dout    (ram_dout    ),
  .ram_wraddr  (ram_wraddr  ),
  .ram_rdaddr  (ram_rdaddr  ),
  .ram_din     (ram_din     ),
  .ram_wren    (ram_wren    )
);

dpram #(
  .DATA_WIDTH (DATA_WIDTH ),
  .ADDR_WIDTH (ADDR_WIDTH )
)dpram_inst
(
  .wrclock   (wrclk      ),
  .wren      (ram_wren   ),
  .wraddress (ram_wraddr ),
  .data      (ram_din    ),
  .rdclock   (rdclk      ),
  .rden      (1'b1       ),
  .rdaddress (ram_rdaddr ),
  .q         (ram_dout   )
);


endmodule