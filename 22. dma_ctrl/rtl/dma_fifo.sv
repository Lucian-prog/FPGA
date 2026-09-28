//-----------------------------------------------------------------------------
// Module: dma_fifo
// Description: 参数化同步 FIFO，用于 DMA 读->写通路的数据缓冲
//
// Parameters:
//   DEPTH  - FIFO 深度，必须为 2 的幂且 >= 2（指针自然回绕依赖该约束）
//   DATA_W - 数据位宽
//
// Interfaces:
//   clk / rst_n          - 时钟（上边沿）与低有效异步复位
//   in_valid/in_ready    - 入队侧 valid/ready 握手，in_ready = !full（组合）
//   out_valid/out_ready  - 出队侧 valid/ready 握手，out_valid = !empty（组合）
//   count                - 当前水位 0..DEPTH，寄存器输出，无毛刺
//
// 设计说明:
//   - 同步 FIFO，读写指针用简单二进制计数（无需 Gray 码），自然回绕。
//   - 满空判断基于计数 count_q，控制逻辑（握手/水位）只依赖指针与计数，
//     不依赖 mem 数据，mem 未初始化产生的 X 不会扩散到控制逻辑。
//   - out_data = mem[rd_ptr_q] 为组合读（分布式 RAM/LUTRAM 友好），
//     复位后 FIFO 为空时 out_data 可能是未初始化数据，下游仅在
//     out_valid=1 时采样。
//   - 同拍入队+出队时计数一加一减保持不变，full 时 in_ready=0 阻止入队，
//     为标准（非 FWFT 穿透）行为。
//-----------------------------------------------------------------------------
module dma_fifo #(
  parameter int DEPTH  = 16,   // 深度，约束为 2 的幂
  parameter int DATA_W = 32    // 数据位宽
) (
  input  logic                 clk,
  input  logic                 rst_n,       // 低有效异步复位
  // 入队侧（valid/ready 握手）
  input  logic                 in_valid,
  output logic                 in_ready,
  input  logic [DATA_W-1:0]    in_data,
  // 出队侧（valid/ready 握手）
  output logic                 out_valid,
  input  logic                 out_ready,
  output logic [DATA_W-1:0]    out_data,
  // 水位
  output logic [$clog2(DEPTH+1)-1:0] count  // 0..DEPTH
);

  // ---------------------------------------------------------------------
  // 参数与内部信号
  // ---------------------------------------------------------------------
  localparam int PTR_W = $clog2(DEPTH);          // 指针位宽（DEPTH>=2 时 >=1）
  localparam int CNT_W = $clog2(DEPTH + 1);      // 水位位宽，可表示 0..DEPTH
  localparam logic [CNT_W-1:0] FULL_CNT = DEPTH; // 满水位常量（与 count_q 同宽，避免符号/位宽比较问题）

  logic [PTR_W-1:0] wr_ptr_q, wr_ptr_d;          // 写指针（二进制，自然回绕）
  logic [PTR_W-1:0] rd_ptr_q, rd_ptr_d;          // 读指针（二进制，自然回绕）
  logic [CNT_W-1:0] count_q,  count_d;           // 水位计数（时序维护，无毛刺）

  logic [DATA_W-1:0] mem [DEPTH];                // 存储阵列，无需复位

  logic full, empty;
  logic do_wr, do_rd;

  // ---------------------------------------------------------------------
  // 参数合法性检查（仅 elaboration/仿真期生效，不影响综合逻辑）
  // DEPTH 非 2 的幂属于非法配置：指针回绕位宽与深度不匹配会导致行为错误
  // ---------------------------------------------------------------------
  initial begin
    if (DEPTH < 2 || (DEPTH & (DEPTH - 1)) != 0)
      $error("dma_fifo: DEPTH must be a power of 2 and >= 2, got %0d", DEPTH);
  end

  // ---------------------------------------------------------------------
  // 握手与满空（组合）
  // ---------------------------------------------------------------------
  assign full     = (count_q == FULL_CNT);
  assign empty    = (count_q == '0);
  assign in_ready = !full;
  assign out_valid = !empty;

  // 握手成功判定：valid 与 ready 同拍为高
  assign do_wr = in_valid  && in_ready;
  assign do_rd = out_valid && out_ready;

  // 出队数据：组合读当前读指针槽位
  assign out_data = mem[rd_ptr_q];

  // 水位输出：寄存器输出，读侧可安全用作触发条件
  assign count = count_q;

  // ---------------------------------------------------------------------
  // 下一值逻辑（组合）
  // 同拍入队+出队：指针各自前进，计数一加一减保持不变
  // ---------------------------------------------------------------------
  always_comb begin
    wr_ptr_d = wr_ptr_q;
    rd_ptr_d = rd_ptr_q;
    count_d  = count_q;
    if (do_wr) begin
      wr_ptr_d = wr_ptr_q + 1'b1;
      count_d  = count_d + 1'b1;
    end
    if (do_rd) begin
      rd_ptr_d = rd_ptr_q + 1'b1;
      count_d  = count_d - 1'b1;
    end
  end

  // ---------------------------------------------------------------------
  // 指针与计数寄存器（异步复位，复位清零；mem 数据不复位）
  // ---------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q  <= '0;
    end else begin
      wr_ptr_q <= wr_ptr_d;
      rd_ptr_q <= rd_ptr_d;
      count_q  <= count_d;
    end
  end

  // ---------------------------------------------------------------------
  // 存储写：仅在入队握手成功拍写入（单口写 + 组合读，LUTRAM 友好）
  // ---------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (do_wr) begin
      mem[wr_ptr_q] <= in_data;
    end
  end

endmodule
