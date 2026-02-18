module div_tb;

  // Parameters
  localparam integer DIV1 = 4;
  localparam integer DIV2 = 5;

  //Ports
  reg  clk;
  reg  rst_n;
  wire clk_out1;
  wire clk_out2;

  div # (
    .DIV(DIV1)
  )
  div_inst1 (
    .clk(clk),
    .rst_n(rst_n),
    .clk_out(clk_out1)
  );
  div # (
    .DIV(DIV2)
  )
    div_inst2 (
        .clk(clk),
        .rst_n(rst_n),
        .clk_out(clk_out2)
    );

//always #5  clk = ! clk ;
    always #5 clk = ~clk;
    initial begin
        $dumpfile("div_tb.vcd");
        $dumpvars(0, div_tb);
        rst_n=0;
        clk=0;
        #20;
        rst_n=1;
        #20000;
        $display("[PASS] div 仿真完成，请查看 div_tb.vcd 波形（DIV4/DIV5波形）");
        $finish;
    end
endmodule