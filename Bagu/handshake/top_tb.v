`timescale 1ps/1ps
module handshake_top_tb;
  // Parameters
parameter PERIOD_A =5;
parameter PERIOD_B =10;
  //Ports
  reg  clka;
  reg  clkb;
  reg  rst_n;
  reg [7:0] data;
  wire [7:0] data_o;

  handshake_top  top_inst (
    .clka(clka),
    .clkb(clkb),
    .rst_n(rst_n),
    .data(data),
    .data_o(data_o)
  );

//always #5  clk = ! clk ;
initial begin
  clka =0;
  forever #(PERIOD_A/2) clka = ~clka;
end

initial begin
  clkb=0;
  forever #(PERIOD_B/2) clkb = ~clkb;
end

initial begin
  rst_n=0;
  data=8'b11110110;
  repeat(10) @(posedge clkb);
  rst_n=1;
  data=8'b11110111;
  repeat(10) @(posedge clkb);
  data=8'b01110010;
  repeat(10) @(posedge clkb);
  data=8'b00000010;
end

initial begin
  repeat(400)@(posedge clkb);
  $finish;
end
initial begin
  $dumpfile("top_tb.vcd");
  $dumpvars(0,handshake_top_tb);
end
endmodule