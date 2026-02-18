module digital_tube_tb;

  // Parameters

  //Ports
  reg  clk;
  reg  rst_n;
  reg [31:0] Disp_Data;
  wire [7:0] SEL;
  wire [7:0] SEG;

  digital_tube  digital_tube_inst (
    .clk(clk),
    .rst_n(rst_n),
    .Disp_Data(Disp_Data),
    .SEL(SEL),
    .SEG(SEG)
  );
  initial clk=1;
//always #5  clk = ! clk ;
  initial begin
    $dumpfile("hex8_tb.vcd");
    $dumpvars(0, digital_tube_tb);
    rst_n=0;
    Disp_Data = 32'h12345678; // Example data
    #201;
    rst_n=1;
    #2000000;
    Disp_Data = 32'h9abcdef;
    #2000000;
    $display("[PASS] hex8 (digital_tube) 仿真完成，请查看 hex8_tb.vcd 波形");
    $finish;
  end
  always #5 clk = !clk; // Clock generation
endmodule
