`timescale 1ns/1ps

module dual_port_ram_tb;
  localparam DATA_WIDTH = 8;
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = 1 << ADDR_WIDTH;
  localparam CLK_PERIOD = 10;

  reg                     clk;
  reg                     resetn;
  reg  [ADDR_WIDTH-1:0]   wr_addr;
  reg  [DATA_WIDTH-1:0]   wr_data;
  reg                     wr_en;
  reg                     rd_en;
  reg  [ADDR_WIDTH-1:0]   rd_addr;
  wire [DATA_WIDTH-1:0]   rd_data;

  reg [DATA_WIDTH-1:0] refmem [0:DEPTH-1];
  integer i;

  dual_port_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) dut (
    .clk(clk),
    .resetn(resetn),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  initial begin
    clk = 0;
    resetn = 0;
    wr_addr = 0;
    wr_data = 0;
    wr_en = 0;
    rd_en = 0;
    rd_addr = 0;
    for (i = 0; i < DEPTH; i = i + 1)
      refmem[i] = 0;

    #20;
    resetn = 1;

    // Write all addresses
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge clk);
      wr_en <= 1'b1;
      wr_addr <= i[ADDR_WIDTH-1:0];
      wr_data <= (i + 8'h10);
      refmem[i] <= (i + 8'h10);
    end
    @(posedge clk);
    wr_en <= 1'b0;

    // Read and check all addresses (sync read)
    rd_en <= 1'b1;
    for (i = 0; i < DEPTH; i = i + 1) begin
      rd_addr <= i[ADDR_WIDTH-1:0];
      @(posedge clk);
      #1;
      if (rd_data !== refmem[i]) begin
        $fatal(1, "Read mismatch at addr %0d: got 0x%0h exp 0x%0h",
               i, rd_data, refmem[i]);
      end
    end
    rd_en <= 1'b0;

    // Simultaneous read/write on different addresses
    @(posedge clk);
    wr_en <= 1'b1;
    wr_addr <= 4'h3;
    wr_data <= 8'hA5;
    refmem[4'h3] <= 8'hA5;
    rd_en <= 1'b1;
    rd_addr <= 4'h7;
    @(posedge clk);
    #1;
    if (rd_data !== refmem[4'h7]) begin
      $fatal(1, "Read mismatch at addr 7: got 0x%0h exp 0x%0h",
             rd_data, refmem[4'h7]);
    end
    wr_en <= 1'b0;
    rd_en <= 1'b0;

    $display("dual_port_ram_tb: PASS");
    $finish;
  end
endmodule
