// =============================================================================
// rv32_alu —— 算术逻辑单元
// -----------------------------------------------------------------------------
// 教学要点：
//   ALU 是数据通路的“计算中心”，本核心支持 5 种运算：
//     运算       服务于哪些指令
//     ADD  —— add / addi / lw / sw（地址计算）/ jal（未被使用但走加法通道）
//     SUB  —— sub，以及 beq 的相等性比较（相减为 0 即相等）
//     AND  —— and / andi
//     OR   —— or / ori
//     SLT  —— slt / slti（有符号比较：a < b 则结果为 1，否则为 0）
//
//   两个输出各有用途：
//     result_o —— 三栖信号：既是运算结果（写回），又是访存地址（lw/sw），
//                 还是 beq 的比较依据（经 zero_o 间接使用）。
//     zero_o   —— 专门为 beq 服务的标志位。分支判断不在 ALU 里做，
//                 而是由控制器把 zero_i 和 branch 控制信号相与得到。
//
//   为什么 ALU 控制码是 3 位而 funct3 也是 3 位，却需要两级译码？
//   因为 add 和 sub 的 funct3 相同（都是 000），要靠 funct7[5] 区分；
//   而且 lw/sw/beq 这些指令根本不看 funct3 就决定用 ADD/SUB。
//   所以主译码器先定“大类”（ALUOp），ALU 译码器再结合 funct 字段
//   定“具体运算”——这就是经典的二级译码结构。
//
//   ALU 是纯组合逻辑；它和数据存储器一起构成了 lw 指令的关键路径。
// =============================================================================
module rv32_alu (
  input  logic [31:0] a_i,            // 操作数 A：总是来自寄存器 rs1
  input  logic [31:0] b_i,            // 操作数 B：rs2 或扩展立即数（上游 MUX 选择）
  input  logic [2:0]  alu_control_i,  // 运算选择，来自 ALU 译码器
  output logic [31:0] result_o,       // 运算结果 / 访存地址
  output logic        zero_o          // 结果为 0 标志，供 beq 判断
);

  localparam logic [2:0] ALU_ADD = 3'b000;
  localparam logic [2:0] ALU_SUB = 3'b001;
  localparam logic [2:0] ALU_AND = 3'b010;
  localparam logic [2:0] ALU_OR  = 3'b011;
  localparam logic [2:0] ALU_SLT = 3'b101;

  // ALU 是纯组合逻辑。SLT 必须把两个操作数解释为有符号补码数：
  // $signed 让比较器按补码语义工作，否则 -1 会被当成巨大的无符号数。
  // SLT 的结果只有最低位有意义（0 或 1），高位补 0。
  always_comb begin
    case (alu_control_i)
      ALU_ADD: result_o = a_i + b_i;
      ALU_SUB: result_o = a_i - b_i;
      ALU_AND: result_o = a_i & b_i;
      ALU_OR:  result_o = a_i | b_i;
      ALU_SLT: result_o = {31'b0, ($signed(a_i) < $signed(b_i))};
      default: result_o = 32'h0000_0000;
    endcase
  end

  // beq 复用减法结果；相减为 0 即表示两个寄存器相等。
  // 这是硬件复用的好例子：不需要专门的比较器，减法器兼做比较。
  assign zero_o = (result_o == 32'h0000_0000);

endmodule
