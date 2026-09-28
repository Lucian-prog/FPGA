// =============================================================================
// rv32_imem_model —— 指令存储器仿真模型（组合读 ROM）
// -----------------------------------------------------------------------------
// 教学要点：
//   这是配合 rv32_core 时序契约的“理想化”指令存储器：
//   地址变化，数据在同一个周期内出现在输出上（组合读）。
//
//   它本质上是一块 ROM：仿真启动时通过 $readmemh 把汇编器生成的
//   十六进制机器码（默认 programs/riscvtest.hex）加载进数组，
//   之后核心只能从里面取指令，没有写端口。
//
//   地址换算：RISC-V 的地址是“字节地址”，而存储数组按 32 位字编址，
//   所以丢掉低 2 位（addr[1:0] 恒为 0，指令 4 字节对齐），
//   用 addr[INDEX_WIDTH+1:2] 作为数组下标。
//   例：DEPTH=64 时 INDEX_WIDTH=6，取下标 addr[7:2]，对应字节地址
//   0x00~0xFC 共 64 条指令的空间。
//
//   注意（README 强调）：真实 FPGA 的 Block RAM 是同步读——地址给出后
//   下一个时钟沿才有数据。直接把这个模型换成 BRAM 会让整条时序错位，
//   所以上板时必须把核心改成多周期或流水线结构。这个组合读模型
//   只用于仿真验证教材数据通路。
// =============================================================================
module rv32_imem_model #(
  parameter int DEPTH = 64,                              // 存储深度（字数）
  parameter INIT_FILE = "programs/riscvtest.hex"         // 机器码初始化文件
) (
  input  logic [31:0] addr_i,   // 取指地址（字节地址，来自核心的 PC）
  output logic [31:0] rdata_o   // 读出的 32 位指令
);

  localparam int INDEX_WIDTH = $clog2(DEPTH);  // 数组下标所需位数

  logic [31:0] mem [0:DEPTH-1];   // 存储阵列：每个元素是一条 32 位指令
  integer i;

  // 教材仿真模型：启动时加载机器码，未使用空间填 0。
  // 填 0 的好处：PC 跑出程序区后取到的是全 0 编码，属于未实现指令，
  // 核心按“安全退化”处理（无写副作用，PC 继续 +4），仿真行为可控。
  initial begin
    for (i = 0; i < DEPTH; i = i + 1) begin
      mem[i] = 32'h0000_0000;
    end
    if (INIT_FILE != "") begin
      $readmemh(INIT_FILE, mem);  // 从 hex 文件加载程序（每行一个 32 位字）
    end
  end

  // 组合读：PC 是字节地址，去掉低 2 位后才得到 32 位字数组下标。
  // 这条 assign 就是“零延迟 ROM”的全部逻辑。
  assign rdata_o = mem[addr_i[INDEX_WIDTH+1:2]];

endmodule
