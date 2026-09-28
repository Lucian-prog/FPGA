`timescale 1ns/1ps

module rv32_alu_tb;

  logic [31:0] a;
  logic [31:0] b;
  logic [2:0]  alu_control;
  logic [31:0] result;
  logic        zero;
  integer      errors;

  rv32_alu dut (
    .a_i           (a),
    .b_i           (b),
    .alu_control_i (alu_control),
    .result_o      (result),
    .zero_o        (zero)
  );

  task automatic check_alu(
    input logic [2:0]  control,
    input logic [31:0] operand_a,
    input logic [31:0] operand_b,
    input logic [31:0] expected_result,
    input logic        expected_zero
  );
    begin
      alu_control = control;
      a = operand_a;
      b = operand_b;
      #1;
      if ((result !== expected_result) || (zero !== expected_zero)) begin
        $display("ALU ERROR: ctrl=%b a=%h b=%h result=%h zero=%b",
                 control, operand_a, operand_b, result, zero);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    errors = 0;

    check_alu(3'b000, 32'd12, 32'd5, 32'd17, 1'b0);
    check_alu(3'b001, 32'd12, 32'd12, 32'd0, 1'b1);
    check_alu(3'b001, 32'd5, 32'd12, 32'hffff_fff9, 1'b0);
    check_alu(3'b010, 32'hf0f0_aa55, 32'h0ff0_0f0f,
             32'h00f0_0a05, 1'b0);
    check_alu(3'b011, 32'hf0f0_0000, 32'h0000_0f0f,
             32'hf0f0_0f0f, 1'b0);
    check_alu(3'b101, 32'hffff_ffff, 32'd1, 32'd1, 1'b0);
    check_alu(3'b101, 32'd1, 32'hffff_ffff, 32'd0, 1'b1);

    if (errors == 0) begin
      $display("PASS: rv32_alu_tb");
      $finish;
    end

    $fatal(1, "FAIL: rv32_alu_tb, errors=%0d", errors);
  end

endmodule
