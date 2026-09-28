
module seq_det_tb;

  // Parameters
 parameter PERIOD = 20;
  //Ports
  reg  clk;
  reg  rst_n;
  reg  din;
  reg  din_valid;
  wire flag;

  seq_det  seq_det_inst (
    .clk(clk),
    .rst_n(rst_n),
    .din(din),
    .din_valid(din_valid),
    .flag(flag)
  );
  initial begin
    repeat(300) @(posedge clk);
    $finish;
  end

  initial begin
    clk = 1'b0;
    forever #(PERIOD/2) clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    din=1'b0;
    din_valid=1'b0;
    repeat(30) @(posedge clk)
    #(PERIOD/6) 
    rst_n = 1'b1;
    din_valid=1'b1;
    #PERIOD
    din=1'b1;
    #PERIOD
    din=1'b0;
    #PERIOD
    din=1'b1;
    #PERIOD
    din=1'b1;
    #PERIOD
    din=1'b0;
    #PERIOD
    din=1'b1;
  end

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, seq_det_tb);
  end

endmodule