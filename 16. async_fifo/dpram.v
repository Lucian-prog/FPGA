// 模块: dpram
// 说明: 双口 RAM（Dual-Port RAM）实现，用于 async_fifo 做底层存储。
// 主要参数:
//  - DATA_WIDTH: 数据宽度
//  - ADDR_WIDTH: 地址宽度（决定深度）
// 主要端口:
//  - wrclock/wren/wraddress/data: 写端口
//  - rdclock/rden/rdaddress/q: 读端口
// 说明/备注:
//  - 根据 ADDR_WIDTH 大小时选择 block RAM 或 distributed RAM 实现，使用合成属性提示。
// -----------------------------------------------------------------------------
module dpram #(
  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 16
)
(
  input                    wrclock,
  input                    wren,
  input  [ADDR_WIDTH-1:0]  wraddress,
  input  [DATA_WIDTH-1:0]  data,
  input                    rdclock,
  input                    rden,
  input  [ADDR_WIDTH-1:0]  rdaddress,
  output [DATA_WIDTH-1:0]  q
);

reg [DATA_WIDTH-1:0] q_wire;

assign q = q_wire;

generate
  if(ADDR_WIDTH>5) begin : use_bram
  //
   (* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];
  always@(posedge wrclock)
    if(wren)
      ram[wraddress] <= data;

  always@(posedge rdclock)
    if(rden)
      q_wire <= ram[rdaddress];
  //
  end
  else begin : use_dram
  //
  (* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];
  always@(posedge wrclock)
    if(wren)
      ram[wraddress] <= data;

  always@(posedge rdclock)
    if(rden)
      q_wire <= ram[rdaddress];
  //
  end
endgenerate


endmodule