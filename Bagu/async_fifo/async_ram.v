module async_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 16
)
(
  input wire clk_wr,
  input wire clk_rd,
  input wire rst_n,
  input wire [DATA_WIDTH-1:0]data_in,
  input wire [$clog2(ADDR_WIDTH)-1:0]addr_wr,
  input wire [$clog2(ADDR_WIDTH)-1:0]addr_rd,
  
  input wire we,
  input wire re,

  output reg [DATA_WIDTH-1:0]data_out
);
  reg [DATA_WIDTH-1:0] ram [0:ADDR_WIDTH-1]; // 16 x 8-bit RAM
  integer i;
  always@(posedge clk_wr or negedge rst_n)begin
    if(!rst_n)begin
      for(i=0;i<ADDR_WIDTH;i++)begin
        ram[i]<=0;
      end
    end
    else if (we)begin
       ram[addr_wr]<=data_in;
    end
    else begin
      ram[addr_wr]<=ram[addr_wr];
    end
  end

  always@(posedge clk_rd or negedge rst_n)begin
    if(!rst_n)begin
      data_out<=0;
    end
    else if(re)begin
      data_out<=ram[addr_rd];
    end
    else begin
      data_out<=data_out;
    end
  end

endmodule