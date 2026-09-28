`timescale 1ps/1ps
//============================================================================
// sync_fifo_tb.v : 用 DDS 正弦源做 FIFO 写侧激励
//----------------------------------------------------------------------------
// 演示场景：
//   1. 写侧全速写（DDS 连续产生正弦样本），前 RD_START 拍读侧不启动
//      -> FIFO 逐渐写满，almost_full 反压冻结 DDS（波形暂停不失真）
//   2. 读侧启动后每 RD_DIV 拍读一次（读慢写快）
//      -> FIFO 周期性满/非满，DDS 随之冻结/恢复，正弦波间歇推进
//   3. 第 FCW_SWEEP 拍 FCW 翻倍，演示 DDS 运行时变频
//
// 验证点（Verdi 里看波形）：
//   - o_rdata / i_wdata 设为 Analog + Signed，就是一段连续正弦
//   - o_full 期间 DDS 相位冻结，恢复后无缝续上（无跳变、无丢样）
//============================================================================
module sync_fifo_tb;
  // Parameters
  localparam DATA_WIDTH = 32;
  localparam DATA_DEPTH = 32;
  parameter PERIOD   = 10;   // 时钟周期（timescale 单位）
  parameter RD_DIV   = 4;    // 读侧分频：每 RD_DIV 拍读一次 -> 读慢写快
  parameter RD_START = 120;  // 读侧延迟启动：先让 FIFO 积压写满
  parameter FCW_SWEEP = 600; // 在这一拍切换频率控制字（变频演示）

  //Ports
  reg  i_sys_clk;
  reg  i_sys_rst_n;
  wire i_wren;
  wire i_rden;
  wire [DATA_WIDTH-1:0] i_wdata;
  wire [DATA_WIDTH-1:0] o_rdata;
  wire  o_full;
  wire  o_empty;

  // DDS 频率控制字：2^26 -> f_clk/64；切换到 2^27 -> f_clk/32
  reg [31:0] fcw;

  // DDS 输出（简化版无 o_valid：i_en=1 的拍即产出样本，wren 直接用使能信号）
  wire signed [DATA_WIDTH-1:0] dds_data;

  //--------------------------------------------------------------------
  // 反压：FIFO 满时冻结 DDS 相位（o_sine 组合直出，样本消费与
  // 相位推进一一对应，~o_full 做使能即可无缝续传）
  //--------------------------------------------------------------------
  assign i_wren  = ~o_full;
  assign i_wdata = dds_data;

  sync_fifo # (
    .DATA_WIDTH(DATA_WIDTH),
    .DATA_DEPTH(DATA_DEPTH)
  )
  sync_fifo_inst (
    .i_sys_clk(i_sys_clk),
    .i_sys_rst_n(i_sys_rst_n),
    .i_wren(i_wren),
    .i_rden(i_rden),
    .i_wdata(i_wdata),
    .o_rdata(o_rdata),
    .o_full(o_full),
    .o_empty(o_empty)
  );

  dds_sine # (
    .PHASE_W(32),
    .LUT_AW (8),
    .OUT_W  (DATA_WIDTH)
  )
  u_dds (
    .i_sys_clk   (i_sys_clk),
    .i_sys_rst_n (i_sys_rst_n),
    .i_en        (~o_full),
    .i_freq_word (fcw),
    .o_sine      (dds_data)
  );

  //--------------------------------------------------------------------
  // 读侧节奏：RD_START 拍后启动，之后每 RD_DIV 拍读 1 个
  //--------------------------------------------------------------------
  reg [8:0] rd_div_cnt;
  reg       rd_run;

  always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
    if (!i_sys_rst_n) begin
      rd_div_cnt <= 9'd0;
      rd_run     <= 1'b0;
    end
    else if (!rd_run) begin
      if (rd_div_cnt == RD_START) begin
        rd_run     <= 1'b1;                 // 积压结束，读侧上线
        rd_div_cnt <= 9'd0;                 // 计数器清零对齐节拍（否则要从 121 一路加到溢出才碰巧回到 3）
      end
      else
        rd_div_cnt <= rd_div_cnt + 9'd1;    // 启动前自由计数（当延迟计时用）
    end
    else begin
      rd_div_cnt <= (rd_div_cnt == RD_DIV-1) ? 9'd0 : rd_div_cnt + 9'd1;
    end
  end

  assign i_rden = rd_run && (rd_div_cnt == RD_DIV-1) && !o_empty;

  //--------------------------------------------------------------------
  // 写/读样本计数，结尾对账：写入 = 读出 + FIFO 内滞留
  //--------------------------------------------------------------------
  integer wr_cnt = 0;
  integer rd_cnt = 0;

  always @(posedge i_sys_clk) begin
    if (i_wren && !o_full) wr_cnt <= wr_cnt + 1;
    if (i_rden && !o_empty) rd_cnt <= rd_cnt + 1;
  end

  //--------------------------------------------------------------------
  // 时钟 / 复位 / 总时长
  //--------------------------------------------------------------------
  initial begin
    i_sys_clk = 1'b0;                        // （原文件此处缺分号，已修复）
    forever #(PERIOD/2) i_sys_clk = ~i_sys_clk;
  end

  initial begin
    i_sys_rst_n = 1'b0;
    repeat (5) @(posedge i_sys_clk);
    i_sys_rst_n = 1'b1;
  end

  initial begin
    fcw = 32'h0400_0000;                     // 2^26 : f_clk/64
    repeat (FCW_SWEEP) @(posedge i_sys_clk);
    fcw = 32'h0800_0000;                     // 2^27 : f_clk/32，频率翻倍
  end

  initial begin
    repeat (1200) @(posedge i_sys_clk);
    $display("[TB] total: written=%0d read=%0d in_fifo=%0d  (check: written == read + in_fifo)",
             wr_cnt, rd_cnt, sync_fifo_inst.fifo_number);
    $finish;
  end

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, sync_fifo_tb);
  end

endmodule
