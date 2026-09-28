`timescale 1ps/1ps
//iverilog -o work .\async_reset.v .\tb_async_reset.v
//vvp -n .\work
//gtkwave .\wave.vcd

module async_reset_tb;

  // Parameters
  parameter PERIOD = 10;
  //Ports
  reg  clk;
  reg  rst_n;
  wire rst_out;

  async_reset  async_reset_inst (
    .clk(clk),
    .rst_n(rst_n),
    .rst_out(rst_out)
  );

//always #5  clk = ! clk ;
  initial begin
    clk = 1'b0;
    forever #(PERIOD/2) clk = ~clk;
  end

  initial begin
    rst_n = 1'b1;
    repeat(5) @(posedge clk);
    rst_n = 1'b0;
    #(PERIOD/4);
    rst_n = 1'b1;
    repeat(20) @(posedge clk);
    $finish;    
  end

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, async_reset_tb);
  end

endmodule