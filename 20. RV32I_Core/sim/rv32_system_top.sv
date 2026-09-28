// =============================================================================
// rv32_system_top —— 整机仿真顶层（核心 + 指令存储器 + 数据存储器）
// -----------------------------------------------------------------------------
// 教学要点：
//   这个模块把 rv32_core 和两个存储器模型组装成一台可以跑程序的
//   完整“计算机”，供 rv32_core_tb 整机测试使用。
//
//   结构对应教材里的最小系统：
//       ┌──────────┐   addr    ┌────────┐
//       │          │ ────────► │  IMEM  │ ── instr ──┐
//       │ rv32_core│           │ (ROM)  │            │
//       │          │ ◄──────── └────────┘            │
//       │          │   addr/wdata/we  ┌────────┐     │
//       │          │ ───────────────► │  DMEM  │     │
//       │          │ ◄───── rdata ─── │ (RAM)  │     │
//       └──────────┘                  └────────┘     │
//
//   对外引出的四个 dmem 信号是整机测试的“观测窗口”：
//   测试平台通过监视 dmem_we_o/dmem_addr_o/dmem_wdata_o，
//   检查程序是否把正确的值写到了正确的地址
//   （教材程序先写 7 → 地址 96，最后写 25 → 地址 100）。
//
//   这也是“核心 vs 系统”的分界：rv32_core 是可综合的处理器 RTL，
//   而这里的存储器是仿真专用模型。将来移植到 FPGA 时，替换的就是
//   这一层——用真正的 BRAM 包装替换两个 model，并相应修改核心的
//   时序假设（见 rv32_imem_model 的注释）。
// =============================================================================
module rv32_system_top #(
  parameter IMEM_INIT_FILE = "programs/riscvtest.hex"  // 要运行的程序
) (
  input  logic        clk_i,         // 系统时钟（由测试平台产生）
  input  logic        rst_n_i,       // 低有效异步复位
  output logic [31:0] imem_addr_o,   // 观测用：当前取指地址（PC）
  output logic [31:0] dmem_addr_o,   // 观测用：数据存储器地址
  output logic [31:0] dmem_wdata_o,  // 观测用：数据存储器写数据
  output logic        dmem_we_o      // 观测用：数据存储器写使能
);

  logic [31:0] instr;        // 指令存储器 → 核心的指令
  logic [31:0] dmem_rdata;   // 数据存储器 → 核心的读数据

  // 处理器核心：可综合 RTL，对外是两个标准存储器接口
  rv32_core u_core (
    .clk_i        (clk_i),
    .rst_n_i      (rst_n_i),
    .imem_addr_o  (imem_addr_o),
    .imem_rdata_i (instr),
    .dmem_addr_o  (dmem_addr_o),
    .dmem_wdata_o (dmem_wdata_o),
    .dmem_we_o    (dmem_we_o),
    .dmem_rdata_i (dmem_rdata)
  );

  // 指令存储器模型：组合读 ROM，启动时加载测试程序
  rv32_imem_model #(
    .DEPTH     (64),               // 64 条指令的空间
    .INIT_FILE (IMEM_INIT_FILE)
  ) u_imem (
    .addr_i  (imem_addr_o),
    .rdata_o (instr)
  );

  // 数据存储器模型：组合读 + 同步写 RAM
  rv32_dmem_model #(
    .DEPTH (64)                    // 64 字 = 256 字节数据空间
  ) u_dmem (
    .clk_i      (clk_i),
    .write_en_i (dmem_we_o),
    .addr_i     (dmem_addr_o),
    .wdata_i    (dmem_wdata_o),
    .rdata_o    (dmem_rdata)
  );

endmodule
