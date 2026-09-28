// =============================================================================
// rv32_main_decoder —— 主译码器（第一级译码）
// -----------------------------------------------------------------------------
// 教学要点：
//   控制器采用教材经典的“两级译码”结构，本模块是第一级：
//   只看 opcode（指令[6:0]），判断指令属于哪一大类，据此产生大部分
//   控制信号。具体做哪种 ALU 运算留给第二级（rv32_alu_decoder）。
//
//   输出信号速查表（✓ 表示该指令类下有效）：
//     opcode     指令类   reg_write mem_write alu_src branch jump result_src imm_src alu_op
//     0000011    lw        ✓                  1（imm）                  MEM      I      ADD
//     0100011    sw                  ✓        1（imm）                           S      ADD
//     0110011    R-type    ✓                  0（rs2）                   ALU             FUNC
//     1100011    beq                                     ✓                      B      BRANCH
//     0010011    I-type    ✓                  1（imm）                   ALU     I      FUNC
//     1101111    jal       ✓                              ✓            PC+4    J      ADD
//
//   控制信号的直觉理解：
//     reg_write  —— 本周期允许写寄存器堆吗？（写体系结构状态的总闸）
//     mem_write  —— 本周期允许写数据存储器吗？（同上，两道总闸是安全核心）
//     alu_src    —— ALU 的 B 操作数用 rs2 还是立即数？
//     result_src —— 写回数据来自 ALU / 存储器 / PC+4？
//     imm_src    —— 按哪种格式拼接立即数？
//     branch/jump—— 声称“我想跳转”，但最终是否生效还要看 zero 和 valid。
//     alu_op     —— 给第二级译码的提示：ADD（地址）/ BRANCH（比较）/ FUNC（看 funct）
//
//   防御性设计：先给所有输出赋“无写副作用”的默认值，case 命中后再
//   覆盖。未实现的 opcode 不会误写任何状态——这是 README 所说的
//   “安全退化行为”，也是写组合逻辑避免 latch 的标准手法。
// =============================================================================
module rv32_main_decoder (
  input  logic [6:0] opcode_i,      // 指令[6:0]，指令大类编码
  output logic [1:0] result_src_o,  // 写回数据来源选择（ALU/MEM/PC+4）
  output logic       mem_write_o,   // 数据存储器写使能（未与 valid 相与，见 controller）
  output logic       branch_o,      // 本指令是分支指令
  output logic       alu_src_o,     // ALU B 操作数：0=rs2，1=立即数
  output logic       reg_write_o,   // 寄存器堆写使能（未与 valid 相与）
  output logic       jump_o,        // 本指令是 jal
  output logic [1:0] imm_src_o,     // 立即数格式选择
  output logic [1:0] alu_op_o,      // 给 ALU 译码器的运算大类提示
  output logic       main_valid_o   // opcode 属于已实现的大类
);

  // RISC-V 基础指令的 opcode 编码（指令[6:0]，低两位恒为 11）
  localparam logic [6:0] OP_LOAD   = 7'b0000011;  // lw 等 load 类
  localparam logic [6:0] OP_STORE  = 7'b0100011;  // sw 等 store 类
  localparam logic [6:0] OP_R_TYPE = 7'b0110011;  // add/sub/and/or/slt
  localparam logic [6:0] OP_BRANCH = 7'b1100011;  // beq 等分支类
  localparam logic [6:0] OP_I_TYPE = 7'b0010011;  // addi/slti/ori/andi
  localparam logic [6:0] OP_JAL    = 7'b1101111;  // jal

  // result_src 编码：写回 MUX 的选择
  localparam logic [1:0] RESULT_ALU = 2'b00;  // ALU 运算结果
  localparam logic [1:0] RESULT_MEM = 2'b01;  // 数据存储器读数（lw）
  localparam logic [1:0] RESULT_PC4 = 2'b10;  // PC+4（jal 保存返回地址）

  // imm_src 编码：立即数格式
  localparam logic [1:0] IMM_I = 2'b00;
  localparam logic [1:0] IMM_S = 2'b01;
  localparam logic [1:0] IMM_B = 2'b10;
  localparam logic [1:0] IMM_J = 2'b11;

  // alu_op 编码：告诉第二级译码“往哪个方向细化”
  localparam logic [1:0] ALU_OP_ADD    = 2'b00;  // 强制加法（地址计算 / jal）
  localparam logic [1:0] ALU_OP_BRANCH = 2'b01;  // 分支比较（减法）
  localparam logic [1:0] ALU_OP_FUNC   = 2'b10;  // 看 funct3/funct7 决定

  // 主译码只识别指令大类。先给出“无写副作用”的默认值，
  // 即使输入是未实现 opcode，也不会误写寄存器或数据存储器。
  // 这种“默认值 + case 覆盖”的写法同时解决了两个问题：
  //   1. 安全性：非法指令天然落入安全默认；
  //   2. 完备性：所有分支都有赋值，不会综合出锁存器。
  always_comb begin
    result_src_o = RESULT_ALU;
    mem_write_o  = 1'b0;
    branch_o     = 1'b0;
    alu_src_o    = 1'b0;
    reg_write_o  = 1'b0;
    jump_o       = 1'b0;
    imm_src_o    = IMM_I;
    alu_op_o     = ALU_OP_ADD;
    main_valid_o = 1'b0;

    case (opcode_i)
      // lw：rs1 + I型imm 得地址 → 读存储器 → 写回 rd
      OP_LOAD: begin
        result_src_o = RESULT_MEM;
        alu_src_o    = 1'b1;        // B 操作数取立即数（地址偏移）
        reg_write_o  = 1'b1;
        imm_src_o    = IMM_I;
        alu_op_o     = ALU_OP_ADD;  // 地址 = 基址 + 偏移，强制加法
        main_valid_o = 1'b1;
      end

      // sw：rs1 + S型imm 得地址，rs2 提供写数据（写数据不经过 ALU）
      OP_STORE: begin
        mem_write_o  = 1'b1;
        alu_src_o    = 1'b1;
        imm_src_o    = IMM_S;
        alu_op_o     = ALU_OP_ADD;
        main_valid_o = 1'b1;
      end

      // R-type：rs1 OP rs2 → rd，具体运算看 funct3/funct7
      OP_R_TYPE: begin
        result_src_o = RESULT_ALU;
        reg_write_o  = 1'b1;
        alu_op_o     = ALU_OP_FUNC;
        main_valid_o = 1'b1;
      end

      // beq：ALU 做减法，zero 有效则 PC ← PC + B型imm
      OP_BRANCH: begin
        branch_o     = 1'b1;
        imm_src_o    = IMM_B;
        alu_op_o     = ALU_OP_BRANCH;
        main_valid_o = 1'b1;
      end

      // I-type：rs1 OP imm → rd，具体运算看 funct3
      OP_I_TYPE: begin
        result_src_o = RESULT_ALU;
        alu_src_o    = 1'b1;
        reg_write_o  = 1'b1;
        imm_src_o    = IMM_I;
        alu_op_o     = ALU_OP_FUNC;
        main_valid_o = 1'b1;
      end

      // jal：rd ← PC+4（返回地址），PC ← PC + J型imm
      OP_JAL: begin
        result_src_o = RESULT_PC4;
        reg_write_o  = 1'b1;
        jump_o       = 1'b1;
        imm_src_o    = IMM_J;
        alu_op_o     = ALU_OP_ADD;  // ALU 本周期无实质任务，给个无害的加法
        main_valid_o = 1'b1;
      end

      default: begin
        // 未实现的 opcode：保持安全默认值，整个核心按“空操作”前进。
      end
    endcase
  end

endmodule
