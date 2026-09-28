`timescale 1ps/1ps
module tb_clk_switch;
//iverilog -o work .\clk_switch.v .\tb_clk_switch.v
//vvp -n .\work
//gtkwave .\wave.vcd

  // Parameters
 parameter PERIOD0 = 10;
 parameter PERIOD1 = 20;
  //Ports
  reg  clk0;
  reg  clk1;
  reg  sel;
  wire  clk_out;

  clk_switch  clk_switch_inst (
    .clk0(clk0),
    .clk1(clk1),
    .sel(sel),
    .clk_out(clk_out)
  );
  initial begin
    clk0 = 1'b0;
    forever #(PERIOD0/2) clk0 = ~clk0;
  end
  
  initial begin
    clk1 = 1'b0;
    forever #(PERIOD1/2) clk1 = ~clk1;
  end

   initial begin
    sel=0;
    repeat(20) @(posedge clk0);
    sel=1;
    repeat(20) @(posedge clk0);
    sel=0;
    $finish;
   end

   initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,tb_clk_switch);
   end
//always #5  clk = ! clk ;

endmodule