`timescale 1ps/1ps
//iverilog -o work .\dmux_tb.v .\dmux.v
//vvp -n .\work
//gtkwave .\dmux_tb.vcd
module dmux_tb; 
  // Parameters
parameter PERIOD1 = 10;
parameter PERIOD2 = 5;
  //Ports
  reg  clk_src;
  reg  rst_n;
  reg  valid;
  reg  clk_dst;
  reg  [7:0]data_in;
  wire [7:0]data_out;

  dmux dmux_inst (
    .clk_src(clk_src),
    .rst_n(rst_n),
    .valid(valid),
    .clk_dst(clk_dst),
    .data_in(data_in),
    .data_out(data_out)
  );

//always #5  clk = ! clk ;
initial begin
  clk_src = 1'b0;
  forever #(PERIOD1/2) clk_src = ~clk_src;
end

initial begin
  clk_dst =1'b0;
  forever #(PERIOD2/2) clk_dst = ~clk_dst;
end

//rst
initial begin
  rst_n=0;
  repeat(10)@(posedge clk_src);
  rst_n=1;
end

//finish
initial begin
  repeat(300)@(posedge clk_src);
  $finish;
end

//data
initial begin
  data_in=8'h2A;
  repeat(20)@(posedge clk_src);
  data_in=8'h3B;
  repeat(20)@(posedge clk_src);
  data_in=8'h4C;
  repeat(20)@(posedge clk_src);
  data_in=8'h5D;
  repeat(20)@(posedge clk_src);
  data_in=8'h6E;
end

//valid
initial begin
  valid=0;
  repeat(10)@(posedge clk_src);
  valid=1;
  repeat(20)@(posedge clk_src);
  valid=0;
  repeat(20)@(posedge clk_src);
  valid=1;
  repeat(20)@(posedge clk_src);
  valid=0;
  repeat(20)@(posedge clk_src);
  valid=1;
  repeat(20)@(posedge clk_src);
  valid=0;
  repeat(20)@(posedge clk_src);
  valid=1;
end

//dumpfile
initial begin
  $dumpfile("dmux_tb.vcd");
  $dumpvars(0,dmux_tb);
end
endmodule