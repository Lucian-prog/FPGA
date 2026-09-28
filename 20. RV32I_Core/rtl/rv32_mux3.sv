// =============================================================================
// rv32_mux3 —— 三选一多路选择器（参数化位宽）
// -----------------------------------------------------------------------------
// 教学要点：
//   这是写回（Write-Back）MUX，决定哪个结果最终写入寄存器堆：
//     select = 00 —— ALU 结果：add/sub/and/or/slt 及 I-type 算术指令；
//     select = 01 —— 数据存储器读数：lw；
//     select = 10 —— PC+4：jal 把“返回地址”保存到 rd。
//
//   观察这三路来源可以体会单周期设计的一个要点：所有可能的数据在
//   同一周期内都被同时算出来，MUX 只是“选答案”，不负责“算答案”。
//   时序代价是选择器本身处于关键路径末端——lw 的数据必须穿过
//   数据存储器再穿过这个 MUX，才能在时钟沿前稳定到寄存器堆写端口。
//
//   default 分支输出 0 是防御性写法：2 位 select 的第 4 种编码
//   理论上不会出现，但写全 default 可以避免综合出锁存器（latch）。
// =============================================================================
module rv32_mux3 #(
  parameter int WIDTH = 32    // 数据位宽，默认 32 位
) (
  input  logic [WIDTH-1:0] data0_i,   // ALU 结果
  input  logic [WIDTH-1:0] data1_i,   // 数据存储器读数据
  input  logic [WIDTH-1:0] data2_i,   // PC+4（jal 返回地址）
  input  logic [1:0]       select_i,  // 来自控制器的 result_src
  output logic [WIDTH-1:0] data_o
);

  always_comb begin
    case (select_i)
      2'b00: data_o = data0_i;
      2'b01: data_o = data1_i;
      2'b10: data_o = data2_i;
      default: data_o = '0;   // 未用编码：输出 0，防止推断出锁存器
    endcase
  end

endmodule
