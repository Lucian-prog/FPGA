 module uart_rx_tb;

  // Parameters

  //Ports
  reg clk;
  reg rst_n;
  reg uart_rx;
  wire rx_done;
  wire [7:0] rx_data;

  uart_rx  uart_rx_inst (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx(uart_rx),
    .rx_done(rx_done),
    .rx_data(rx_data)
  );

//always #5  clk = ! clk ;
initial clk=1;
always #10 clk=~clk;

initial begin
    rst_n=0;
    #201;
    rst_n=1;
    uart_rx=1;
    #200;
    //9'b0101_0101
    uart_rx=0;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=1;

    #(5208*20*10);
    uart_rx=0;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=1;
    #(5208*20*10);
    uart_rx=0;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=0;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=1;
    #(5208*20);
    uart_rx=1;
  $stop;
end
endmodule
