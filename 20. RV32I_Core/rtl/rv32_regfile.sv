// =============================================================================
// rv32_regfile —— 32×32 位通用寄存器堆
// -----------------------------------------------------------------------------
// 教学要点：
//   寄存器堆是处理器的第二类体系结构状态（第一类是 PC）。
//   RISC-V 规定有 32 个通用寄存器 x0~x31，每条指令用 5 位字段寻址：
//     rs1 = instr[19:15]  源寄存器 1
//     rs2 = instr[24:20]  源寄存器 2
//     rd  = instr[11:7]   目的寄存器
//
//   端口结构是经典的“两读一写”（2R1W）：
//     - 两个读端口是组合逻辑：地址变化，数据同周期出现。
//       这样单周期内就能“读出操作数 → ALU 运算 → 写回结果”。
//     - 写端口是时序逻辑：结果在时钟上升沿才真正落入存储阵列。
//       这条边界保证了同一周期内“先读后写”，不会产生竞争。
//
//   x0 的特殊处理是 RISC-V 的 ISA 约定：x0 恒为 0。硬件上用两道
//   保险实现——读端口遇地址 0 直接旁路返回 0；写端口拒绝写地址 0。
//   因此寄存器堆不需要整体复位（省 32 个复位端），x0 永远正确。
//
//   综合提示：在 FPGA 上这种小容量 2R1W 阵列通常用触发器或
//   分布式 RAM（LUTRAM）实现；寄存器堆太小，用不上 Block RAM。
// =============================================================================
module rv32_regfile (
  input  logic        clk_i,        // 时钟（写端口使用）
  input  logic        write_en_i,   // 写使能，来自控制器的 reg_write
  input  logic [4:0]  read_addr1_i, // 读地址 1（rs1 字段）
  input  logic [4:0]  read_addr2_i, // 读地址 2（rs2 字段）
  input  logic [4:0]  write_addr_i, // 写地址（rd 字段）
  input  logic [31:0] write_data_i, // 写数据（写回 MUX 的输出）
  output logic [31:0] read_data1_o, // 读数据 1 → ALU 的 A 操作数
  output logic [31:0] read_data2_o  // 读数据 2 → ALU 源 MUX / sw 写数据
);

  logic [31:0] regs_q [0:31];   // 32 个 32 位寄存器组成的存储阵列

  // 两个读端口是组合逻辑。x0 不依赖存储阵列内容，始终直接返回 0。
  // 这就是“读旁路”：即使阵列里 regs_q[0] 存了垃圾值（未复位），
  // 外部看到的 x0 依然是 0。
  always_comb begin
    read_data1_o = (read_addr1_i == 5'd0) ? 32'h0000_0000
                                         : regs_q[read_addr1_i];
    read_data2_o = (read_addr2_i == 5'd0) ? 32'h0000_0000
                                         : regs_q[read_addr2_i];
  end

  // 写端口在时钟上升沿提交。禁止写 x0，避免破坏 ISA 规定的常量零。
  // 注意没有复位端：x0 由上面的旁路和这里的写抑制共同保证，
  // 其余寄存器上电初值无所谓——软件约定程序使用前先写入。
  always_ff @(posedge clk_i) begin
    if (write_en_i && (write_addr_i != 5'd0)) begin
      regs_q[write_addr_i] <= write_data_i;
    end
  end

endmodule
