`timescale 1ns/1ps

module counter (
  input wire clk,
  input wire rst_n,
  input wire en_i,
  output reg [3:0] count_o
);
  // 4 位寄存器自然截断：15 再加 1 回到 0。
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      count_o <= 4'd0;
    else if (en_i)
      count_o <= count_o + 4'd1;
  end
endmodule
