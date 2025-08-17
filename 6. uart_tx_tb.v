module uart_tx_tb;

  // Parameters

  //Ports
  reg clk;
  reg rst_n;
  reg [7:0] data_in;
  wire uart_tx;
  wire led;

  uart_tx uart_tx_inst (
      .clk(clk),
      .rst_n(rst_n),
      .data_in(data_in),
      .uart_tx(uart_tx),
      .led(led)
  );
  defparam uart_tx_inst.BAND_DLY_CNT_MAX = 500000-1;
  always #5 clk = !clk;
  initial begin
    clk   = 0;
    rst_n = 0;
    #230
    rst_n = 1;
    data_in = 8'b01010101;
    #30000000
    data_in = 8'b10101010;
    #30000000
   $finish;
  end


endmodule
