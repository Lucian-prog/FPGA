`timescale 1ns/1ps

module rv32_regfile_tb;

  logic        clk;
  logic        write_en;
  logic [4:0]  read_addr1;
  logic [4:0]  read_addr2;
  logic [4:0]  write_addr;
  logic [31:0] write_data;
  logic [31:0] read_data1;
  logic [31:0] read_data2;
  integer      errors;

  rv32_regfile dut (
    .clk_i        (clk),
    .write_en_i   (write_en),
    .read_addr1_i (read_addr1),
    .read_addr2_i (read_addr2),
    .write_addr_i (write_addr),
    .write_data_i (write_data),
    .read_data1_o (read_data1),
    .read_data2_o (read_data2)
  );

  always #5 clk = ~clk;

  task automatic write_reg(
    input logic [4:0]  addr,
    input logic [31:0] data
  );
    begin
      @(negedge clk);
      write_en = 1'b1;
      write_addr = addr;
      write_data = data;
      @(posedge clk);
      #1;
      write_en = 1'b0;
    end
  endtask

  initial begin
    clk = 1'b0;
    write_en = 1'b0;
    write_addr = 5'd0;
    write_data = 32'd0;
    read_addr1 = 5'd0;
    read_addr2 = 5'd0;
    errors = 0;

    write_reg(5'd5, 32'h1234_5678);
    write_reg(5'd7, 32'hcafe_babe);

    read_addr1 = 5'd5;
    read_addr2 = 5'd7;
    #1;
    if ((read_data1 !== 32'h1234_5678) ||
        (read_data2 !== 32'hcafe_babe)) begin
      $display("REGFILE ERROR: dual combinational read");
      errors = errors + 1;
    end

    // 对 x0 的写请求必须被抑制，两个读端口均应返回 0。
    write_reg(5'd0, 32'hffff_ffff);
    read_addr1 = 5'd0;
    read_addr2 = 5'd0;
    #1;
    if ((read_data1 !== 32'd0) || (read_data2 !== 32'd0)) begin
      $display("REGFILE ERROR: x0 changed");
      errors = errors + 1;
    end

    if (errors == 0) begin
      $display("PASS: rv32_regfile_tb");
      $finish;
    end

    $fatal(1, "FAIL: rv32_regfile_tb, errors=%0d", errors);
  end

endmodule
