`timescale 1ns/1ps

module spi_master_tb;
  localparam DATA_W = 8;
  localparam DIV = 4;
  localparam CLK_PERIOD = 10;

  reg                 clk;
  reg                 rst_n;
  reg                 start;
  reg  [DATA_W-1:0]   tx_data;
  reg                 miso;
  wire                sclk;
  wire                cs_n;
  wire                mosi;
  wire [DATA_W-1:0]   rx_data;
  wire                busy;
  wire                done;

  reg [DATA_W-1:0]    slave_shift;
  integer             timeout;

  spi_master #(
    .DATA_W(DATA_W),
    .DIV(DIV)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .tx_data(tx_data),
    .miso(miso),
    .sclk(sclk),
    .cs_n(cs_n),
    .mosi(mosi),
    .rx_data(rx_data),
    .busy(busy),
    .done(done)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  // Simple slave model: update MISO on falling edge (Mode 0)
  always @(negedge sclk) begin
    if (!cs_n) begin
      miso <= slave_shift[DATA_W-1];
      slave_shift <= {slave_shift[DATA_W-2:0], 1'b0};
    end
  end

  initial begin
    clk = 0;
    rst_n = 0;
    start = 0;
    tx_data = 8'hA5;
    miso = 0;
    slave_shift = 8'h3C;

    #40;
    rst_n = 1;

    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    timeout = 2000;
    while (!done && timeout > 0) begin
      @(posedge clk);
      timeout = timeout - 1;
    end

    if (timeout == 0) begin
      $fatal(1, "Timeout waiting for done");
    end

    if (rx_data !== 8'h3C) begin
      $fatal(1, "RX mismatch: got 0x%0h exp 0x3C", rx_data);
    end

    $display("spi_master_tb: PASS");
    $finish;
  end
endmodule
