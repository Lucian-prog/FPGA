`timescale 1ns / 1ps
module crc16_tb;
  reg clk;
  reg rst_n;
  reg clear;
  reg [7:0] data_in;
  reg data_valid;
  wire [15:0] crc_out;

  crc16 dut (
    .clk(clk),
    .rst_n(rst_n),
    .clear(clear),
    .data_in(data_in),
    .data_valid(data_valid),
    .crc_out(crc_out)
  );

  always #5 clk = ~clk;

  task send_byte(input [7:0] value);
    begin
      data_in = value;
      data_valid = 1'b1;
      @(posedge clk);
      data_valid = 1'b0;
      data_in = 8'h00;
      @(posedge clk);
    end
  endtask

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    clear = 1'b0;
    data_in = 8'h00;
    data_valid = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    clear = 1'b1;
    @(posedge clk);
    clear = 1'b0;

    send_byte("1");
    send_byte("2");
    send_byte("3");
    send_byte("4");
    send_byte("5");
    send_byte("6");
    send_byte("7");
    send_byte("8");
    send_byte("9");

    if (crc_out == 16'h29B1) begin
      $display("CRC16 PASS: %h", crc_out);
    end else begin
      $display("CRC16 FAIL: %h (expect 29B1)", crc_out);
    end

    #20;
    $finish;
  end
endmodule
