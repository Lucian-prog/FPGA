`timescale 1ns/1ps

module rv32_imm_ext_tb;

  logic [31:0] instr;
  logic [1:0]  imm_src;
  logic [31:0] imm_ext;
  integer      errors;
  logic [12:0] b_imm;
  logic [20:0] j_imm;

  rv32_imm_ext dut (
    .instr_i   (instr),
    .imm_src_i (imm_src),
    .imm_ext_o (imm_ext)
  );

  task automatic check_value(input logic [31:0] expected);
    begin
      #1;
      if (imm_ext !== expected) begin
        $display("IMM ERROR: src=%b instr=%h result=%h expected=%h",
                 imm_src, instr, imm_ext, expected);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    errors = 0;

    // I-type：最大正数与最小 12 位负数。
    instr = 32'h0000_0000;
    instr[31:20] = 12'h7ff;
    imm_src = 2'b00;
    check_value(32'h0000_07ff);

    instr[31:20] = 12'h800;
    check_value(32'hffff_f800);

    // S-type：把 -16 分散写入 instr[31:25] 和 instr[11:7]。
    instr = 32'h0000_0000;
    instr[31:25] = 7'h7f;
    instr[11:7] = 5'h10;
    imm_src = 2'b01;
    check_value(32'hffff_fff0);

    // B-type：教材中的 beq 指令携带 +48 字节偏移。
    instr = 32'h0272_8863;
    imm_src = 2'b10;
    check_value(32'd48);

    // B-type：自行拼出 -4，检查符号扩展和最低位补 0。
    b_imm = 13'h1ffc;
    instr = 32'h0000_0000;
    instr[31] = b_imm[12];
    instr[7] = b_imm[11];
    instr[30:25] = b_imm[10:5];
    instr[11:8] = b_imm[4:1];
    check_value(32'hffff_fffc);

    // J-type：教材 jal 携带 +8 字节偏移。
    instr = 32'h0080_01ef;
    imm_src = 2'b11;
    check_value(32'd8);

    // J-type：自行拼出 -4。
    j_imm = 21'h1ffffc;
    instr = 32'h0000_0000;
    instr[31] = j_imm[20];
    instr[19:12] = j_imm[19:12];
    instr[20] = j_imm[11];
    instr[30:21] = j_imm[10:1];
    check_value(32'hffff_fffc);

    if (errors == 0) begin
      $display("PASS: rv32_imm_ext_tb");
      $finish;
    end

    $fatal(1, "FAIL: rv32_imm_ext_tb, errors=%0d", errors);
  end

endmodule
