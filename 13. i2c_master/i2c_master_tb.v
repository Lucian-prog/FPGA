`timescale 1ns/1ps

module i2c_master_tb;
  localparam DATA_W = 8;
  localparam CLK_PERIOD = 10;

  reg                 clk;
  reg                 rst_n;
  reg                 start;
  reg  [6:0]          addr;
  reg                 rw;
  reg  [DATA_W-1:0]   tx_data;
  reg                 scl_in;
  wire [DATA_W-1:0]   rx_data;
  wire                busy;
  wire                done;
  wire                ack_error;
  wire                scl;
  wire                sda;

  reg                 sda_slave_oe;
  reg [7:0]           slave_shift;
  reg [7:0]           addr_shift;
  reg [3:0]           bit_cnt;
  reg [2:0]           slave_state;

  localparam SL_IDLE    = 3'd0;
  localparam SL_ADDR    = 3'd1;
  localparam SL_ADDRACK = 3'd2;
  localparam SL_DATA    = 3'd3;
  localparam SL_DATAACK = 3'd4;

  pullup(sda);
  assign sda = sda_slave_oe ? 1'b0 : 1'bz;

  i2c_master #(
    .DATA_W(DATA_W)
  ) dut (
    .scl_in(scl_in),
    .rst_n(rst_n),
    .start(start),
    .addr(addr),
    .rw(rw),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .busy(busy),
    .done(done),
    .ack_error(ack_error),
    .scl(scl),
    .sda(sda)
  );

  always #(CLK_PERIOD/2) clk = ~clk;
  always #(CLK_PERIOD/2) scl_in = ~scl_in;

  // Simple slave: ACKs address and data, and returns one byte on read.
  always @(posedge scl) begin
    if (slave_state == SL_ADDR) begin
      addr_shift <= {addr_shift[6:0], sda};
      if (bit_cnt == 0) begin
        slave_state <= SL_ADDRACK;
        bit_cnt <= 7;
      end else begin
        bit_cnt <= bit_cnt - 1'b1;
      end
    end else if (slave_state == SL_DATA) begin
      if (!addr_shift[0]) begin
        if (bit_cnt == 0) begin
          slave_state <= SL_DATAACK;
          bit_cnt <= 7;
        end else begin
          bit_cnt <= bit_cnt - 1'b1;
        end
      end else begin
        if (bit_cnt == 0) begin
          slave_state <= SL_DATAACK;
          bit_cnt <= 7;
        end else begin
          bit_cnt <= bit_cnt - 1'b1;
        end
      end
    end
  end

  always @(negedge scl) begin
    case (slave_state)
      SL_ADDRACK: begin
        sda_slave_oe <= 1'b1;
        slave_state <= SL_DATA;
        slave_shift <= 8'h3C;
      end
      SL_DATAACK: begin
        sda_slave_oe <= 1'b1;
        slave_state <= SL_IDLE;
      end
      SL_DATA: begin
        if (addr_shift[0]) begin
          sda_slave_oe <= ~slave_shift[7];
          slave_shift <= {slave_shift[6:0], 1'b0};
        end else begin
          sda_slave_oe <= 1'b0;
        end
      end
      default: begin
        sda_slave_oe <= 1'b0;
      end
    endcase
  end

  // Detect START: SDA falling while SCL high
  always @(negedge sda) begin
    if (scl) begin
      slave_state <= SL_ADDR;
      addr_shift <= 0;
      bit_cnt <= 7;
    end
  end

  initial begin
    clk = 0;
    scl_in = 0;
    rst_n = 0;
    start = 0;
    addr = 7'h42;
    rw = 1'b0;
    tx_data = 8'hA5;
    sda_slave_oe = 1'b0;
    slave_shift = 8'h3C;
    addr_shift = 0;
    bit_cnt = 7;
    slave_state = SL_IDLE;

    #40;
    rst_n = 1;

    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    wait (done);
    if (ack_error) begin
      $fatal(1, "Write transaction NACK");
    end

    rw <= 1'b1;
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    wait (done);
    if (rx_data !== 8'h3C) begin
      $fatal(1, "Read mismatch: got 0x%0h exp 0x3C", rx_data);
    end

    $display("i2c_master_tb: PASS");
    $finish;
  end
endmodule
