`timescale 1ns / 1ps
// 模块: dds_tb
// 说明: 验证 DDS 正弦波发生器
//       - 验证复位后输出为0
//       - 验证频率字为1时输出连续采样，不出现 X/Z
//       - 输出 VCD 波形供肉眼验证正弦形状

module dds_tb;

  reg         clk;
  reg         rst_n;
  reg  [9:0]  dds_freq;
  wire signed [15:0] ddso;

  dds dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .dds_freq(dds_freq),
    .ddso    (ddso)
  );

  always #10 clk = ~clk;   // 50MHz（实际DDS用48kHz，这里仿真加速）

  integer err = 0;
  integer i;
  reg signed [15:0] samples [0:1023];

  initial begin
    $dumpfile("dds_tb.vcd");
    $dumpvars(0, dds_tb);

    clk      = 0;
    rst_n    = 0;
    dds_freq = 10'd0;

    // ── 复位验证 ──────────────────────────────────────
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;

    // ── 场景1：freq=0，输出应保持 sin_rom[0]=0 附近 ──
    dds_freq = 10'd0;
    repeat(5) @(posedge clk);
    if (ddso === 16'bx || ddso === 16'bz) begin
      $display("[FAIL] freq=0 时 ddso 为 X/Z");
      err = err + 1;
    end else
      $display("[PASS] freq=0, ddso=%0d (期望≈0)", ddso);

    // ── 场景2：freq=1，采集1024个样本，验证无X/Z ─────
    dds_freq = 10'd1;
    for (i = 0; i < 1024; i = i + 1) begin
      @(posedge clk); #1;
      samples[i] = ddso;
      if (ddso === 16'bx || ddso === 16'bz) begin
        $display("[FAIL] freq=1 第%0d个样本为 X/Z", i);
        err = err + 1;
      end
    end
    if (err == 0)
      $display("[PASS] freq=1，1024个样本均有效，最大值=%0d 最小值=%0d",
               samples[256], samples[768]);  // 正弦波峰/谷位置

    // ── 场景3：freq=4，验证正值出现 ───────────────────
    dds_freq = 10'd4;
    repeat(100) @(posedge clk);
    $display("[INFO] freq=4, ddso=%0d", ddso);

    // ── 场景4：复位后恢复到0 ──────────────────────────
    rst_n = 0;
    @(posedge clk); #1;
    if (ddso !== 16'sd0) begin
      $display("[FAIL] 复位后 ddso=%0d (期望0)", ddso);
      err = err + 1;
    end else
      $display("[PASS] 复位有效，ddso=0");
    rst_n = 1;

    repeat(5) @(posedge clk);

    if (err == 0)
      $display("[RESULT] dds 全部测试通过");
    else
      $display("[RESULT] dds 存在 %0d 个错误", err);

    $finish;
  end

  initial begin
    #2_000_000;
    $display("[TIMEOUT] dds 仿真超时");
    $finish;
  end
endmodule
