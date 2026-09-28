// =============================================================================
// rv32_core —— 单周期 RV32I 教学核（顶层）
// -----------------------------------------------------------------------------
// 教学要点：
//   这是整个设计的顶层，把控制器和数据通路拼在一起，对外只暴露
//   两个存储器接口：指令存储器（只读）和数据存储器（读写）。
//
//   哈佛结构：指令和数据走两个独立接口。单周期处理器必须这样做——
//   一个周期内既要取指令、又要（可能）读写数据，共享存储器会冲突。
//
//   接口时序契约（与 sim 目录的存储器模型配套，详见 README）：
//     - 指令存储器：组合读。imem_addr_o（即 PC）变化，imem_rdata_i
//       必须同周期返回指令。
//     - 数据存储器：组合读 + 同步写。lw 的读数同周期返回；sw 在
//       dmem_we_o=1 的时钟沿把 dmem_wdata_o 写入 dmem_addr_o 处。
//
//   控制器 ↔ 数据通路的信号对应关系值得对照着看：
//     控制器输出 result_src/pc_src/alu_src/reg_write/imm_src/alu_control
//       → 数据通路同名输入（“指挥”）；
//     数据通路输出 zero
//       → 控制器 zero_i（beq 判断所需的唯一“反馈”）；
//     指令的 opcode/funct3/funct7 直接送给控制器
//       → 整条指令同时也送给数据通路（取 rs/rd 字段和立即数）。
//
//   连线即设计：这个顶层没有任何逻辑，全部是端口互连。
//   读懂每个信号“从哪来、到哪去”，就读懂了单周期处理器。
// =============================================================================
module rv32_core (
  input  logic        clk_i,         // 系统时钟
  input  logic        rst_n_i,       // 低有效异步复位（只复位 PC）

  // ---- 指令存储器接口（组合读）----
  output logic [31:0] imem_addr_o,   // 取指地址 = 当前 PC（字节地址）
  input  logic [31:0] imem_rdata_i,  // 取回的 32 位指令

  // ---- 数据存储器接口（组合读 + 同步写）----
  output logic [31:0] dmem_addr_o,   // 访存地址 = ALU 结果（字节地址）
  output logic [31:0] dmem_wdata_o,  // 写数据 = rs2 寄存器内容
  output logic        dmem_we_o,     // 写使能（仅有效 sw 周期拉高）
  input  logic [31:0] dmem_rdata_i   // 读数据（lw 用）
);

  // 控制器 → 数据通路的控制信号
  logic [1:0] result_src;
  logic       pc_src;
  logic       alu_src;
  logic       reg_write;
  logic [1:0] imm_src;
  logic [2:0] alu_control;
  // 数据通路 → 控制器的反馈
  logic       zero;
  // 控制器输出的指令合法性标志（本层未用，留给上层观察/扩展）
  logic       instr_valid;

  // 控制器回答“本条指令让各 MUX 和写使能取什么值”。
  // 指令的三个译码字段直接切片送入；mem_write 把关后直接驱动 dmem_we_o。
  rv32_controller u_controller (
    .opcode_i      (imem_rdata_i[6:0]),
    .funct3_i      (imem_rdata_i[14:12]),
    .funct7_i      (imem_rdata_i[31:25]),
    .zero_i        (zero),
    .result_src_o  (result_src),
    .mem_write_o   (dmem_we_o),      // 控制器的写使能 = 存储器写使能
    .pc_src_o      (pc_src),
    .alu_src_o     (alu_src),
    .reg_write_o   (reg_write),
    .imm_src_o     (imm_src),
    .alu_control_o (alu_control),
    .instr_valid_o (instr_valid)
  );

  // 数据通路执行组合传播，并在时钟沿提交 PC 和寄存器堆写回。
  // 注意三个对外接口的直接对应：
  //   pc_o        → imem_addr_o（取指地址）
  //   alu_result_o→ dmem_addr_o（访存地址）
  //   instr_i     ← imem_rdata_i（整条指令进数据通路，取字段用）
  rv32_datapath u_datapath (
    .clk_i         (clk_i),
    .rst_n_i       (rst_n_i),
    .result_src_i  (result_src),
    .pc_src_i      (pc_src),
    .alu_src_i     (alu_src),
    .reg_write_i   (reg_write),
    .imm_src_i     (imm_src),
    .alu_control_i (alu_control),
    .instr_i       (imem_rdata_i),
    .dmem_rdata_i  (dmem_rdata_i),
    .zero_o        (zero),
    .pc_o          (imem_addr_o),
    .alu_result_o  (dmem_addr_o),
    .dmem_wdata_o  (dmem_wdata_o)
  );

endmodule
