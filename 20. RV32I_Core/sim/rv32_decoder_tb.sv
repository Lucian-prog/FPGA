`timescale 1ns/1ps

module rv32_decoder_tb;

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic       zero;
  logic [1:0] result_src;
  logic       mem_write;
  logic       pc_src;
  logic       alu_src;
  logic       reg_write;
  logic [1:0] imm_src;
  logic [2:0] alu_control;
  logic       instr_valid;
  integer     errors;

  rv32_controller dut (
    .opcode_i      (opcode),
    .funct3_i      (funct3),
    .funct7_i      (funct7),
    .zero_i        (zero),
    .result_src_o  (result_src),
    .mem_write_o   (mem_write),
    .pc_src_o      (pc_src),
    .alu_src_o     (alu_src),
    .reg_write_o   (reg_write),
    .imm_src_o     (imm_src),
    .alu_control_o (alu_control),
    .instr_valid_o (instr_valid)
  );

  task automatic check_controls(
    input logic [1:0] expected_result_src,
    input logic       expected_mem_write,
    input logic       expected_pc_src,
    input logic       expected_alu_src,
    input logic       expected_reg_write,
    input logic [1:0] expected_imm_src,
    input logic [2:0] expected_alu_control,
    input logic       expected_valid
  );
    begin
      #1;
      if ((result_src !== expected_result_src) ||
          (mem_write !== expected_mem_write) ||
          (pc_src !== expected_pc_src) ||
          (alu_src !== expected_alu_src) ||
          (reg_write !== expected_reg_write) ||
          (imm_src !== expected_imm_src) ||
          (alu_control !== expected_alu_control) ||
          (instr_valid !== expected_valid)) begin
        $display("DECODER ERROR: op=%b f3=%b f7=%b zero=%b",
                 opcode, funct3, funct7, zero);
        $display("  got: rs=%b mw=%b pc=%b as=%b rw=%b imm=%b alu=%b valid=%b",
                 result_src, mem_write, pc_src, alu_src, reg_write,
                 imm_src, alu_control, instr_valid);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    errors = 0;
    zero = 1'b0;
    funct7 = 7'b0000000;

    // lw / sw
    opcode = 7'b0000011; funct3 = 3'b010;
    check_controls(2'b01, 1'b0, 1'b0, 1'b1, 1'b1,
                   2'b00, 3'b000, 1'b1);
    opcode = 7'b0100011; funct3 = 3'b010;
    check_controls(2'b00, 1'b1, 1'b0, 1'b1, 1'b0,
                   2'b01, 3'b000, 1'b1);

    // R-type add/sub/slt/or/and
    opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0000000;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b1,
                   2'b00, 3'b000, 1'b1);
    funct7 = 7'b0100000;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b1,
                   2'b00, 3'b001, 1'b1);
    funct7 = 7'b0000000; funct3 = 3'b010;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b1,
                   2'b00, 3'b101, 1'b1);
    funct3 = 3'b110;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b1,
                   2'b00, 3'b011, 1'b1);
    funct3 = 3'b111;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b1,
                   2'b00, 3'b010, 1'b1);

    // I-type addi/slti/ori/andi
    opcode = 7'b0010011; funct3 = 3'b000;
    check_controls(2'b00, 1'b0, 1'b0, 1'b1, 1'b1,
                   2'b00, 3'b000, 1'b1);
    funct3 = 3'b010;
    check_controls(2'b00, 1'b0, 1'b0, 1'b1, 1'b1,
                   2'b00, 3'b101, 1'b1);
    funct3 = 3'b110;
    check_controls(2'b00, 1'b0, 1'b0, 1'b1, 1'b1,
                   2'b00, 3'b011, 1'b1);
    funct3 = 3'b111;
    check_controls(2'b00, 1'b0, 1'b0, 1'b1, 1'b1,
                   2'b00, 3'b010, 1'b1);

    // beq 未命中与命中。
    opcode = 7'b1100011; funct3 = 3'b000; zero = 1'b0;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b0,
                   2'b10, 3'b001, 1'b1);
    zero = 1'b1;
    check_controls(2'b00, 1'b0, 1'b1, 1'b0, 1'b0,
                   2'b10, 3'b001, 1'b1);

    // jal 总是选择 PC+imm，并把 PC+4 写回 rd。
    opcode = 7'b1101111; funct3 = 3'b000; zero = 1'b0;
    check_controls(2'b10, 1'b0, 1'b1, 1'b0, 1'b1,
                   2'b11, 3'b000, 1'b1);

    // 未实现编码不得产生寄存器写、内存写或跳转副作用。
    opcode = 7'b1111111; funct3 = 3'b000; funct7 = 7'b0000000;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b0,
                   2'b00, 3'b000, 1'b0);
    opcode = 7'b1100011; funct3 = 3'b001; zero = 1'b1;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b0,
                   2'b10, 3'b000, 1'b0);
    opcode = 7'b0000011; funct3 = 3'b000; zero = 1'b0;
    check_controls(2'b01, 1'b0, 1'b0, 1'b1, 1'b0,
                   2'b00, 3'b000, 1'b0);
    opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0000001;
    check_controls(2'b00, 1'b0, 1'b0, 1'b0, 1'b0,
                   2'b00, 3'b000, 1'b0);

    if (errors == 0) begin
      $display("PASS: rv32_decoder_tb");
      $finish;
    end

    $fatal(1, "FAIL: rv32_decoder_tb, errors=%0d", errors);
  end

endmodule
