`timescale 1ps/1ps
// dds_sine_tb.v : 裸测 DDS 本体——连续使能 64 拍（FCW=2^26 -> 64 拍/周期），
// 打印一个完整周期的样本，肉眼/脚本核对是否为标准正弦
module dds_sine_tb;
  reg clk = 0, rst_n = 0;
  reg  [31:0] fcw;
  wire signed [31:0] sine;

  dds_sine #(.PHASE_W(32), .LUT_AW(8), .OUT_W(32)) u_dds (
    .i_sys_clk(clk), .i_sys_rst_n(rst_n),
    .i_en(1'b1), .i_freq_word(fcw), .o_sine(sine)
  );

  always #5 clk = ~clk;

  integer i;
  initial begin
    fcw = 32'h0400_0000;             // 2^26 -> 64 拍一个周期
    repeat (3) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);
    for (i = 0; i < 64; i = i + 1) begin
      @(posedge clk);
      $display("%0d %0d", i, sine);  // 每拍一个样本
    end
    $finish;
  end
endmodule
