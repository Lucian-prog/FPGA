// =============================================================================
// rv32_datapath —— 数据通路
// -----------------------------------------------------------------------------
// 教学要点：
//   数据通路负责“保存并搬运数据”，包含全部体系结构状态（PC、寄存器堆）
//   和处理数据的组合逻辑（ALU、加法器、立即数扩展、MUX）。
//   控制器给什么信号，它就怎么连——它是“执行者”，不是“决策者”。
//
//   建议对照教材图 7.x 的数据通路图，沿着一条指令的数据流读代码。
//   整个通路可以分成四段，对应代码中的四个注释区块：
//
//   ① 取指与下一 PC 计算
//        pc_o 送往指令存储器（在核心外部），同周期内两个加法器并行算出
//        PC+4 和 PC+imm，PC MUX 按 pc_src_i 选其一作为 pc_next。
//
//   ② 读寄存器与立即数扩展
//        指令字段直接充当寄存器堆读地址（rs1/rs2/rd 位置固定），
//        同时立即数扩展器按 imm_src_i 拼出 imm_ext。
//        这两件事并行发生，互不依赖——RISC-V 编码固定字段位置的好处。
//
//   ③ ALU 运算
//        ALU 的 A 固定是 rs1，B 由 alu_src_i 在 rs2 与 imm 之间选择。
//        结果同时是：运算结果（R/I-type）、访存地址（lw/sw）、
//        比较依据（beq 看 zero_o）。
//
//   ④ 写回
//        写回 MUX 在 ALU 结果 / 存储器读数 / PC+4 中选一路，
//        在时钟沿写入寄存器堆的 rd 端口。
//
//   时序视角：①~④ 全部在一个时钟周期内完成。lw 走的路径最长
//   （PC→取指→读寄存器→ALU→数据存储器→写回MUX→寄存器堆写口），
//   它决定了这个处理器的最高时钟频率——这就是“关键路径”。
// =============================================================================
module rv32_datapath (
  input  logic        clk_i,         // 时钟（PC 和寄存器堆使用）
  input  logic        rst_n_i,       // 低有效异步复位（只复位 PC）
  // ---- 来自控制器的控制信号 ----
  input  logic [1:0]  result_src_i,  // 写回来源选择
  input  logic        pc_src_i,      // 下一 PC 选择：0=PC+4，1=PC+imm
  input  logic        alu_src_i,     // ALU B 操作数选择
  input  logic        reg_write_i,   // 寄存器堆写使能
  input  logic [1:0]  imm_src_i,     // 立即数格式选择
  input  logic [2:0]  alu_control_i, // ALU 运算选择
  // ---- 来自核心外部的数据 ----
  input  logic [31:0] instr_i,       // 当前指令（指令存储器读数）
  input  logic [31:0] dmem_rdata_i,  // 数据存储器读数（lw 用）
  // ---- 送往控制器 / 核心外部 ----
  output logic        zero_o,        // ALU 零标志 → 控制器（beq 判断）
  output logic [31:0] pc_o,          // 当前 PC → 指令存储器地址
  output logic [31:0] alu_result_o,  // ALU 结果 → 数据存储器地址
  output logic [31:0] dmem_wdata_o   // 存储器写数据（rs2 直通）
);

  logic [31:0] pc_next;        // 下一 PC（PC MUX 输出）
  logic [31:0] pc_plus4;       // 顺序执行地址
  logic [31:0] pc_target;      // 分支/跳转目标地址
  logic [31:0] imm_ext;        // 扩展后的 32 位立即数
  logic [31:0] reg_rdata1;     // rs1 读数
  logic [31:0] reg_rdata2;     // rs2 读数
  logic [31:0] alu_src_b;      // ALU 的 B 操作数（MUX 输出）
  logic [31:0] writeback_data; // 写回数据（写回 MUX 输出）

  // ==================== ① 取指与下一 PC 计算 ====================
  // 下一 PC 数据流：顺序执行使用 PC+4，分支/跳转使用 PC+imm。
  // 两个加法器并行计算，MUX 只负责选择——“都算出来再选”是单周期的常态。
  rv32_pc u_pc (
    .clk_i     (clk_i),
    .rst_n_i   (rst_n_i),
    .pc_next_i (pc_next),
    .pc_o      (pc_o)
  );

  // 加法器 1：PC + 4（指令定长 4 字节）
  rv32_adder u_pc_plus4_adder (
    .a_i   (pc_o),
    .b_i   (32'd4),
    .sum_o (pc_plus4)
  );

  // 加法器 2：PC + imm（beq/jal 的目标地址，imm 已经符号扩展）
  rv32_adder u_pc_target_adder (
    .a_i   (pc_o),
    .b_i   (imm_ext),
    .sum_o (pc_target)
  );

  // PC 选择 MUX：控制器通过 pc_src_i 决定顺序执行还是跳转
  rv32_mux2 #(
    .WIDTH (32)
  ) u_pc_mux (
    .data0_i  (pc_plus4),
    .data1_i  (pc_target),
    .select_i (pc_src_i),
    .data_o   (pc_next)
  );

  // ==================== ② 读寄存器与立即数扩展 ====================
  // 指令字段直接给出寄存器地址；真正的数据在组合读端口上出现。
  // 注意 rs1/rs2/rd 的位段位置在所有指令格式中固定不变，
  // 所以可以在译码完成前就发起寄存器读——读出来用不上也没关系。
  rv32_regfile u_regfile (
    .clk_i        (clk_i),
    .write_en_i   (reg_write_i),
    .read_addr1_i (instr_i[19:15]),  // rs1 字段
    .read_addr2_i (instr_i[24:20]),  // rs2 字段
    .write_addr_i (instr_i[11:7]),   // rd 字段
    .write_data_i (writeback_data),
    .read_data1_o (reg_rdata1),
    .read_data2_o (reg_rdata2)
  );

  // 立即数扩展：与寄存器读并行进行
  rv32_imm_ext u_imm_ext (
    .instr_i   (instr_i),
    .imm_src_i (imm_src_i),
    .imm_ext_o (imm_ext)
  );

  // ==================== ③ ALU 运算 ====================
  // ALU 的第二操作数在 rs2 与扩展立即数之间选择：
  //   R-type / beq → rs2；I-type / lw / sw → 立即数。
  rv32_mux2 #(
    .WIDTH (32)
  ) u_alu_src_mux (
    .data0_i  (reg_rdata2),
    .data1_i  (imm_ext),
    .select_i (alu_src_i),
    .data_o   (alu_src_b)
  );

  rv32_alu u_alu (
    .a_i           (reg_rdata1),
    .b_i           (alu_src_b),
    .alu_control_i (alu_control_i),
    .result_o      (alu_result_o),   // 直连 dmem_addr_o：ALU 结果即访存地址
    .zero_o        (zero_o)
  );

  // sw 的写数据来自 rs2，与用于地址计算的立即数是两条独立数据流。
  // 这就是 S 型指令需要两个 rs 字段都要读的原因：
  //   rs1 → ALU 算地址；rs2 → 直通存储器写数据口。
  assign dmem_wdata_o = reg_rdata2;

  // ==================== ④ 写回 ====================
  // 写回端口可选择 ALU 结果、内存读数据或 jal 的 PC+4。
  rv32_mux3 #(
    .WIDTH (32)
  ) u_writeback_mux (
    .data0_i  (alu_result_o),   // R-type / I-type 的运算结果
    .data1_i  (dmem_rdata_i),   // lw 的存储器读数
    .data2_i  (pc_plus4),       // jal 的返回地址
    .select_i (result_src_i),
    .data_o   (writeback_data)
  );

endmodule
