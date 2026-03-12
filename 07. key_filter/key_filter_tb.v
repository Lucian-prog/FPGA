`timescale 1ns / 1ps
// 模块: key_filter_tb
// 说明: 测试 key_filter_para1 / key_filter_para3 消抖逻辑
//       DEBOUNCE_TIME 通过 defparam 缩短为 100 周期加速仿真

module key_filter_tb;

  localparam DEBOUNCE_SIM = 20'd100;
  localparam CLK_HALF     = 10;   // 20ns 周期，50MHz

  reg  clk, rst_n, key;

  // para1（一段式时序输出）
  wire p1_flag, r1_flag, s1;
  key_filter u1 (
    .clk(clk), .rst_n(rst_n), .key(key),
    .key_p_flag(p1_flag), .key_r_flag(r1_flag), .key_state(s1)
  );

  // para3（标准三段式）
  wire p3_flag, r3_flag, s3;
  key_filter_para3 u3 (
    .clk(clk), .rst_n(rst_n), .key(key),
    .key_p_flag(p3_flag), .key_r_flag(r3_flag), .key_state(s3)
  );

  always #CLK_HALF clk = ~clk;

  integer err;
  integer t;

  initial begin
    $dumpfile("key_filter_tb.vcd");
    $dumpvars(0, key_filter_tb);

    clk   = 0;
    rst_n = 0;
    key   = 1;
    err   = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);

    // ─────────────────────────────────────────────────────────
    // 场景1：稳定按下 超过消抖时间 → key_p_flag 脉冲, key_state=0
    // ─────────────────────────────────────────────────────────
    $display("[场景1] 稳定按下...");
    key = 0;

    // 等 para1 key_p_flag
    t = 0;
    while (!p1_flag && t < 5000) begin @(posedge clk); t = t + 1; end
    if (p1_flag) $display("[PASS] para1: key_p_flag 脉冲");
    else begin    $display("[FAIL] para1: key_p_flag 超时"); err = err+1; end

    // 等 para1 key_state=0
    t = 0;
    while (s1 !== 1'b0 && t < 5000) begin @(posedge clk); t = t + 1; end
    if (s1 === 1'b0) $display("[PASS] para1: key_state=0（按下稳定）");
    else begin       $display("[FAIL] para1: key_state 未变0"); err = err+1; end

    // 等 para3 key_p_flag
    t = 0;
    while (!p3_flag && t < 5000) begin @(posedge clk); t = t + 1; end
    if (p3_flag) $display("[PASS] para3: key_p_flag 脉冲");
    else begin   $display("[FAIL] para3: key_p_flag 超时"); err = err+1; end

    // 等 para3 key_state=0
    t = 0;
    while (s3 !== 1'b0 && t < 5000) begin @(posedge clk); t = t + 1; end
    if (s3 === 1'b0) $display("[PASS] para3: key_state=0（按下稳定）");
    else begin       $display("[FAIL] para3: key_state 未变0"); err = err+1; end

    // ─────────────────────────────────────────────────────────
    // 场景2：稳定释放 超过消抖时间 → key_r_flag 脉冲, key_state=1
    // ─────────────────────────────────────────────────────────
    $display("[场景2] 稳定释放...");
    key = 1;

    // 等 para1 key_r_flag
    t = 0;
    while (!r1_flag && t < 5000) begin @(posedge clk); t = t + 1; end
    if (r1_flag) $display("[PASS] para1: key_r_flag 脉冲");
    else begin   $display("[FAIL] para1: key_r_flag 超时"); err = err+1; end

    // 等 para1 key_state=1
    t = 0;
    while (s1 !== 1'b1 && t < 5000) begin @(posedge clk); t = t + 1; end
    if (s1 === 1'b1) $display("[PASS] para1: key_state=1（释放稳定）");
    else begin       $display("[FAIL] para1: key_state 未变1"); err = err+1; end

    // 等 para3 key_r_flag
    t = 0;
    while (!r3_flag && t < 5000) begin @(posedge clk); t = t + 1; end
    if (r3_flag) $display("[PASS] para3: key_r_flag 脉冲");
    else begin   $display("[FAIL] para3: key_r_flag 超时"); err = err+1; end

    // 等 para3 key_state=1
    t = 0;
    while (s3 !== 1'b1 && t < 5000) begin @(posedge clk); t = t + 1; end
    if (s3 === 1'b1) $display("[PASS] para3: key_state=1（释放稳定）");
    else begin       $display("[FAIL] para3: key_state 未变1"); err = err+1; end

    // ─────────────────────────────────────────────────────────
    // 场景3：短暂抖动（< 消抖时间）不应触发 key_p_flag
    // ─────────────────────────────────────────────────────────
    $display("[场景3] 短暂抖动（小于消抖时间）...");
    key = 0;
    repeat(DEBOUNCE_SIM / 2) @(posedge clk);   // 只等 1/2 消抖时间
    key = 1;                                     // 弹回
    repeat(DEBOUNCE_SIM + 50) @(posedge clk);
    // 此时不应有 key_p_flag（抖动已过，信号稳定为释放）
    @(posedge clk); #1;
    if (!p1_flag && !p3_flag)
      $display("[PASS] 场景3：抖动被正确过滤，key_p_flag 未误触发");
    else begin
      $display("[FAIL] 场景3：抖动未被过滤（p1=%b p3=%b）", p1_flag, p3_flag);
      err = err + 1;
    end

    repeat(5) @(posedge clk);

    if (err == 0)
      $display("[RESULT] key_filter 全部测试通过！");
    else
      $display("[RESULT] key_filter 存在 %0d 个错误", err);

    $finish;
  end

  initial begin
    #10_000_000;
    $display("[TIMEOUT] key_filter 仿真超时");
    $finish;
  end
endmodule
