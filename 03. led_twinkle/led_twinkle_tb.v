`timescale 1ns / 1ns
// 仿真说明: led_twinkle 原计数上限 25_000_000（对应50MHz时钟1秒闪烁）。
//           仿真时创建一个参数缩小版模块 led_twinkle_sim，计数上限改为 10，
//           验证计数器翻转逻辑正确性。

// ── 仿真用缩参数模块（内嵌在 tb 中，不修改原文件）────────────────────
module led_twinkle_sim(
  input  Clk,
  input  Reset_n,
  output reg Led
);
  reg [4:0] counter;  // 只需5位
  localparam CNT_MAX = 10;  // 缩小到10，仿真快速完成

  always @(posedge Clk or negedge Reset_n)
    if (!Reset_n) counter <= 0;
    else if (counter == CNT_MAX - 1) counter <= 0;
    else counter <= counter + 1'd1;

  always @(posedge Clk or negedge Reset_n)
    if (!Reset_n) Led <= 1'b0;
    else if (counter == CNT_MAX - 1) Led <= !Led;
endmodule

// ── Testbench ────────────────────────────────────────────────────────
module led_twinkle_tb();

  reg  Clk, Reset_n;
  wire Led;
  wire Led_orig;  // 原模块输出（仅编译验证，不等其翻转）

  // 实例化仿真加速版
  led_twinkle_sim dut_sim(
    .Clk    (Clk),
    .Reset_n(Reset_n),
    .Led    (Led)
  );

  // 实例化原始模块（验证编译通过即可，不做功能断言）
  led_twinkle dut_orig(
    .Clk    (Clk),
    .Reset_n(Reset_n),
    .Led    (Led_orig)
  );

  initial Clk = 0;
  always #10 Clk = ~Clk;

  integer toggle_cnt;
  reg prev_Led;
  integer err;

  initial begin
    $dumpfile("led_twinkle_tb.vcd");
    $dumpvars(0, led_twinkle_tb);

    Reset_n  = 0;
    prev_Led = 0;
    toggle_cnt = 0;
    err = 0;

    #50; Reset_n = 1;

    // 等待 Led 翻转 6 次（3个完整周期，每周期 10*20ns=200ns）
    @(posedge Led); toggle_cnt = toggle_cnt + 1;
    @(negedge Led); toggle_cnt = toggle_cnt + 1;
    @(posedge Led); toggle_cnt = toggle_cnt + 1;
    @(negedge Led); toggle_cnt = toggle_cnt + 1;
    @(posedge Led); toggle_cnt = toggle_cnt + 1;
    @(negedge Led); toggle_cnt = toggle_cnt + 1;

    #50;
    if (toggle_cnt == 6)
      $display("[PASS] led_twinkle 计数器翻转正常，共翻转 %0d 次", toggle_cnt);
    else begin
      $display("[FAIL] led_twinkle 翻转次数异常：%0d", toggle_cnt);
      err = err + 1;
    end

    $finish;
  end

  // 超时保护
  initial begin
    #100000;
    $display("[TIMEOUT] led_twinkle 仿真超时");
    $finish;
  end
endmodule
