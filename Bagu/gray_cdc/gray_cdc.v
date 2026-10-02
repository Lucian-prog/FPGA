module gray_cdc(
  input wire clka,
  input wire clkb,
  input wire [3:0] din,
  output wire [3:0] dout
);
  wire [3:0] gray_din;
  assign gray_din =(din>>1)^din;
  reg [3:0] gray_sync0,gray_sync1;
  
  always@(posedge clkb)begin
    gray_sync0<=gray_din;
    gray_sync1<=gray_sync0;
  end

  assign dout = gray_sync1;
endmodule