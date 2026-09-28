// =============================================================================
// rv32_controller —— 控制器（两级译码 + 跳转决策 + 写使能把关）
// -----------------------------------------------------------------------------
// 教学要点：
//   控制器回答一个问题：“这条指令让数据通路的各个 MUX 和写使能取什么值？”
//   它本身不搬运任何数据，只产生控制信号——控制/数据分离是处理器设计的
//   基本分工。
//
//   结构上是三个部分的组合：
//     1. 主译码器：看 opcode，产出大部分控制信号（第一级）；
//     2. ALU 译码器：结合 funct3/funct7，确定具体 ALU 运算（第二级）；
//     3. 本层的“胶水逻辑”：把两级译码的 valid 相与，生成最终写使能
//        和 PC 选择信号。
//
//   为什么要做 valid 双重确认？
//   主译码器只看 opcode 大类，可能“放行”一条它以为支持、实际功能字段
//   未实现的指令（例如 lb 与 lw 同 opcode）。只有当两级译码都确认
//   “这条指令我完整支持”，instr_valid_o 才为 1，reg_write / mem_write
//   才被允许拉高。这就是 README 所说的“安全退化”：非法指令不会破坏
//   任何体系结构状态，PC 安静地 +4 走过。
//
//   pc_src 的逻辑体现了分支决策链：
//     beq 跳转条件 = 是分支指令(branch) 且 比较结果为零(zero)
//     jal 跳转条件 = 是跳转指令(jump)（无条件）
//     二者再与 instr_valid 相与——非法指令连跳转都不允许。
// =============================================================================
module rv32_controller (
  input  logic [6:0] opcode_i,      // 指令[6:0]
  input  logic [2:0] funct3_i,      // 指令[14:12]
  input  logic [6:0] funct7_i,      // 指令[31:25]
  input  logic       zero_i,        // ALU 的零标志（beq 判断依据）
  output logic [1:0] result_src_o,  // 写回来源：00=ALU，01=存储器，10=PC+4
  output logic       mem_write_o,   // 数据存储器写使能（已把关）
  output logic       pc_src_o,      // 下一 PC 选择：0=PC+4，1=PC+imm
  output logic       alu_src_o,     // ALU B 操作数：0=rs2，1=立即数
  output logic       reg_write_o,   // 寄存器堆写使能（已把关）
  output logic [1:0] imm_src_o,     // 立即数格式：I/S/B/J
  output logic [2:0] alu_control_o, // ALU 运算选择
  output logic       instr_valid_o  // 本条指令被完整实现
);

  // 两级译码的“原始”输出：还没与 instr_valid 相与，
  // 所以用 _dec 后缀与最终输出区分。
  logic       mem_write_dec;
  logic       branch_dec;
  logic       reg_write_dec;
  logic       jump_dec;
  logic [1:0] alu_op;       // 主译码 → ALU 译码的大类提示
  logic       main_valid;   // 第一级确认：opcode 大类合法
  logic       alu_valid;    // 第二级确认：具体功能已实现

  // 第一级：opcode → 控制信号草图
  rv32_main_decoder u_main_decoder (
    .opcode_i     (opcode_i),
    .result_src_o (result_src_o),
    .mem_write_o  (mem_write_dec),
    .branch_o     (branch_dec),
    .alu_src_o    (alu_src_o),
    .reg_write_o  (reg_write_dec),
    .jump_o       (jump_dec),
    .imm_src_o    (imm_src_o),
    .alu_op_o     (alu_op),
    .main_valid_o (main_valid)
  );

  // 第二级：alu_op + funct3/funct7 → 具体 ALU 控制码
  rv32_alu_decoder u_alu_decoder (
    .opcode_i      (opcode_i),
    .funct3_i      (funct3_i),
    .funct7_i      (funct7_i),
    .alu_op_i      (alu_op),
    .alu_control_o (alu_control_o),
    .alu_valid_o   (alu_valid)
  );

  // 只有两级译码均确认支持该指令时，才允许改变体系结构状态。
  // 注意：result_src / alu_src / imm_src / alu_control 这些“无害”信号
  // 不需要把关——只要写使能被拦住，MUX 选什么都无所谓（结果不会被提交）。
  // 这正是“控制写使能即可控制一切副作用”的设计哲学。
  assign instr_valid_o = main_valid && alu_valid;
  assign reg_write_o   = reg_write_dec && instr_valid_o;
  assign mem_write_o   = mem_write_dec && instr_valid_o;

  // 普通指令选择 PC+4；有效且满足条件的 beq 或 jal 才选择 PC+imm。
  // 数据通路的 PC 选择 MUX 由这一位驱动。
  assign pc_src_o = instr_valid_o &&
                    ((branch_dec && zero_i) || jump_dec);

endmodule
