module mult_unit #(
  parameter M=4,
  parameter N=4
)(
  input wire clk,
  input wire rst_n,
  input wire mult_en,
  input wire [M+N-1:0] mult1,
  input wire [N-1:0] mult2,
  input wire [M+N-1:0] i_mult_acc,
  output wire mult_valid,
  output reg [M+N-1:0] mult_shift1,
  output reg [N-1:0] mult_shift2,
  output reg [M+N-1:0] o_mult_acc
);
  reg valid_r;
  assign mult_valid=valid_r;
  always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
      mult_shift1<=0;
      mult_shift2<=0;
      o_mult_acc<=0;
      valid_r<=1'b0;
    end
    else if(mult_en)begin
      mult_shift1<=mult1<<1;
      mult_shift2<=mult2>>1;
      valid_r<=1'b1;
      o_mult_acc<=mult2[0]?i_mult_acc+mult1:i_mult_acc;
    end
    else begin
      valid_r<=1'b0;
      o_mult_acc<=0;
      mult_shift1<=0;
      mult_shift2<=0;
    end
  end

endmodule
