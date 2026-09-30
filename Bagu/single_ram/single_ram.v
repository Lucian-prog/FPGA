module single_ram (
  input wire clk,
  input wire rst_n,
  input wire [3:0] addr,
  input wire [7:0] data_in,
  input wire we,
  output reg [7:0] data_out 
);
  reg [7:0] ram [0:15]; // 16 x 8-bit RAM
  integer i;
  always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
      data_out<=0;
      for(i=0;i<15;i++)begin
        ram[i]<=0;
      end
    end

    else if(we)begin
      ram[addr]<=data_in;
    end

    else begin
      data_out<=ram[addr];
    end
  end
  
endmodule