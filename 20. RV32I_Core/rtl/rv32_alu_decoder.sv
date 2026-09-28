// =============================================================================
// rv32_alu_decoder —— ALU 译码器（第二级译码）
// -----------------------------------------------------------------------------
// 教学要点：
//   第二级译码的任务：把主译码器给出的“大类提示”（alu_op_i）与指令中
//   的 funct3 / funct7 字段组合，生成 ALU 真正执行的 3 位控制码。
//
//   为什么需要第二级？主译码只看 opcode，但同一个 opcode 下的具体运算
//   由 funct 字段区分，而且存在编码重叠：
//     - add 和 sub 的 funct3 都是 000，只能靠 funct7[5] 区分；
//     - lw/sw/jal 根本不看 funct，直接强制 ADD；
//     - beq 不看 funct（本核心只实现 beq），直接强制 SUB。
//
//   alu_valid_o 的意义：主译码的 main_valid 只确认“大类合法”，
//   这里的 alu_valid 进一步确认“具体功能也实现了”。例如：
//     - lb/lh（opcode 同 lw，但 funct3≠010）→ 大类合法，功能未实现；
//     - 某 R-type 扩展指令（funct7 不认识）→ 同样拒绝。
//   controller 把两个 valid 相与，都通过才允许写状态——双重确认。
//
//   R-type 用 {funct7, funct3} 10 位拼接做精确匹配，宁可多比较也不
//   模糊匹配：避免把 M 扩展（mul/div，funct7=0000001）误判为基础指令。
// =============================================================================
module rv32_alu_decoder (
  input  logic [6:0] opcode_i,      // 用于区分 R-type / I-type / load / store / jal
  input  logic [2:0] funct3_i,      // 指令[14:12]，功能选择低位
  input  logic [6:0] funct7_i,      // 指令[31:25]，R-type 的扩展功能码
  input  logic [1:0] alu_op_i,      // 主译码器给出的运算大类
  output logic [2:0] alu_control_o, // 送往 ALU 的 3 位运算控制码
  output logic       alu_valid_o    // 具体功能已实现
);

  // 需要用 opcode 区分“同一个 alu_op 下的不同指令家族”
  localparam logic [6:0] OP_R_TYPE = 7'b0110011;
  localparam logic [6:0] OP_I_TYPE = 7'b0010011;
  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_JAL    = 7'b1101111;

  // 与主译码器一致的 alu_op 编码
  localparam logic [1:0] ALU_OP_ADD    = 2'b00;
  localparam logic [1:0] ALU_OP_BRANCH = 2'b01;
  localparam logic [1:0] ALU_OP_FUNC   = 2'b10;

  // 与 rv32_alu 一致的控制码（两边必须同步修改！）
  localparam logic [2:0] ALU_ADD = 3'b000;
  localparam logic [2:0] ALU_SUB = 3'b001;
  localparam logic [2:0] ALU_AND = 3'b010;
  localparam logic [2:0] ALU_OR  = 3'b011;
  localparam logic [2:0] ALU_SLT = 3'b101;

  // 第二级译码把 ALUOp 与 funct 字段组合成具体运算。
  // 对 R-type 检查完整 funct7，避免把未实现扩展误当成基础指令。
  // 默认值同样是防御性的：ALU_ADD 无写副作用（写使能由 valid 把关），
  // alu_valid_o=0 表示“我不认识这条指令”。
  always_comb begin
    alu_control_o = ALU_ADD;
    alu_valid_o   = 1'b0;

    case (alu_op_i)
      // 地址计算类：lw/sw 强制加法；jal 也走这条通道（ALU 结果不被使用）
      ALU_OP_ADD: begin
        alu_control_o = ALU_ADD;
        // 本工程只实现 32 位 lw/sw（funct3=010）；lb/lh/lbu/lhu/sb/sh
        // 与 lw/sw 共享 opcode，必须靠 funct3 把它们排除掉，否则
        // 一条未实现的 lb 会被当成 lw 执行——静默错误比报错更可怕。
        if (((opcode_i == OP_LOAD) || (opcode_i == OP_STORE)) &&
            (funct3_i == 3'b010)) begin
          alu_valid_o = 1'b1;
        end else if (opcode_i == OP_JAL) begin
          alu_valid_o = 1'b1;
        end
      end

      // 分支类：本核心只实现 beq（funct3=000），用减法判断相等
      ALU_OP_BRANCH: begin
        if (funct3_i == 3'b000) begin
          alu_control_o = ALU_SUB;
          alu_valid_o   = 1'b1;
        end
        // bne/blt/bge 等（funct3 其他值）保持无效，不会误跳转
      end

      // 运算类：R-type 看 funct7+funct3，I-type 只看 funct3
      ALU_OP_FUNC: begin
        if (opcode_i == OP_R_TYPE) begin
          // R-type：funct7 参与译码，10 位精确匹配
          case ({funct7_i, funct3_i})
            {7'b0000000, 3'b000}: begin   // add
              alu_control_o = ALU_ADD;
              alu_valid_o   = 1'b1;
            end
            {7'b0100000, 3'b000}: begin   // sub（与 add 仅差 funct7[5]）
              alu_control_o = ALU_SUB;
              alu_valid_o   = 1'b1;
            end
            {7'b0000000, 3'b010}: begin   // slt
              alu_control_o = ALU_SLT;
              alu_valid_o   = 1'b1;
            end
            {7'b0000000, 3'b110}: begin   // or
              alu_control_o = ALU_OR;
              alu_valid_o   = 1'b1;
            end
            {7'b0000000, 3'b111}: begin   // and
              alu_control_o = ALU_AND;
              alu_valid_o   = 1'b1;
            end
            default: begin
              // 未实现的 R-type 功能（如 M 扩展 mul/div）保持无效。
            end
          endcase
        end else if (opcode_i == OP_I_TYPE) begin
          // I-type：没有 funct7 概念（高位是立即数），只看 funct3
          case (funct3_i)
            3'b000: begin                 // addi
              alu_control_o = ALU_ADD;
              alu_valid_o   = 1'b1;
            end
            3'b010: begin                 // slti
              alu_control_o = ALU_SLT;
              alu_valid_o   = 1'b1;
            end
            3'b110: begin                 // ori
              alu_control_o = ALU_OR;
              alu_valid_o   = 1'b1;
            end
            3'b111: begin                 // andi
              alu_control_o = ALU_AND;
              alu_valid_o   = 1'b1;
            end
            default: begin
              // 移位（slli 等）、xori 等未实现 I-type 功能保持无效。
            end
          endcase
        end
      end

      default: begin
        // 保持安全默认值。
      end
    endcase
  end

endmodule
