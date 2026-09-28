`timescale 1ns/1ps
//================================================================
// top_pll_tb.v - PLL 自检测试平台（重写版）
// 修正原版问题：
//   1. A 生成半周期/全周期混淆（原版 target=250 实际输出 99.6kHz）
//   2. 无自动判定 → 增加锁定超时判定 + 频率读数容差检查 + PASS/FAIL 汇总
//   3. locked 刷屏打印 → 仅状态变化时打印
//   4. 不使用跨模块层次引用，避免工具兼容性问题
// 测试场景：200kHz 初始锁定 → 跳变 220/240/180kHz 各检查重锁与读数
//================================================================
module top_pll_tb;

    // 测量窗口缩短（原 100ms 窗口仿真太慢，2ms 窗口精度 0.25% 足够）
    localparam MEAS_CYCLES_TB = 32'd100_000;
    // 一个测量窗口的时长（ns）= MEAS_CYCLES * 20ns
    localparam WIN_NS = MEAS_CYCLES_TB * 20;

    reg        sys_clk;
    reg        reset;
    reg        A;
    wire       B;
    wire [31:0] freq;
    wire       locked;
    wire [31:0] phase_out;

    // 时钟 50MHz
    initial sys_clk = 1'b0;
    always #10 sys_clk = ~sys_clk;

    // 参考信号 A：以半周期 clk 数生成（修正：半周期 125 clk = 200kHz）
    reg  [31:0] a_half_clks;
    integer     a_cnt;
    initial begin
        a_half_clks = 32'd125;  // 200kHz：半周期 125 clk
        a_cnt = 0;
        A = 1'b0;
    end
    always @(posedge sys_clk) begin
        if (a_cnt >= a_half_clks - 1) begin
            a_cnt <= 0;
            A <= ~A;
        end else begin
            a_cnt <= a_cnt + 1;
        end
    end

    // DUT
    top_pll #(
        .MEAS_CYCLES (MEAS_CYCLES_TB)
    ) uut (
        .sys_clk   (sys_clk),
        .reset     (reset),
        .A         (A),
        .B         (B),
        .freq      (freq),
        .locked    (locked),
        .phase_out (phase_out)
    );

    // locked 状态变化打印（避免刷屏）
    reg locked_d;
    always @(posedge sys_clk) begin
        locked_d <= locked;
        if (locked != locked_d)
            $display("[%0t ns] locked -> %b (freq=%0d Hz)", $time, locked, freq);
    end

    // 结果统计
    integer errors;

    // 任务：等待锁定并检查频率读数（容差 3%）
    task check_lock(input [31:0] expect_hz, input integer timeout_ms);
        integer waited;
        begin
            waited = 0;
            while (locked !== 1'b1 && waited < timeout_ms) begin
                #1_000_000; // 1ms 步进等待
                waited = waited + 1;
            end
            if (locked !== 1'b1) begin
                errors = errors + 1;
                $display("[FAIL] %0d Hz: not locked within %0d ms", expect_hz, timeout_ms);
            end else begin
                // 连续等两个测量窗口：第一个窗口可能跨越频率跳变时刻，
                // freq_out 是窗口结束才锁存的保持值，需丢弃后读纯窗口
                #(2 * WIN_NS);
                if (freq > expect_hz + expect_hz/32 ||
                    freq < expect_hz - expect_hz/32) begin
                    errors = errors + 1;
                    $display("[FAIL] %0d Hz: freq readback %0d Hz (err > 3%%)",
                             expect_hz, freq);
                end else begin
                    $display("[PASS] %0d Hz: locked, readback %0d Hz",
                             expect_hz, freq);
                end
            end
        end
    endtask

    // 主流程
    initial begin
        $dumpfile("top_pll_tb.vcd");
        $dumpvars(0, top_pll_tb);

        reset  = 1'b1;
        errors = 0;
        #200;
        reset  = 1'b0;
        $display("[%0t ns] PLL Test Start (A = 200kHz)", $time);

        // 场景 1：初始锁定 200kHz
        check_lock(32'd200_000, 8);

        // 场景 2~4：频率跳变
        $display("[%0t ns] Jump to 220kHz", $time);
        a_half_clks = 32'd114;  // 50MHz/114/2 ≈ 219.3kHz
        check_lock(32'd220_000, 8);

        $display("[%0t ns] Jump to 240kHz", $time);
        a_half_clks = 32'd104;  // 50MHz/104/2 ≈ 240.4kHz
        check_lock(32'd240_000, 8);

        $display("[%0t ns] Jump to 180kHz", $time);
        a_half_clks = 32'd139;  // 50MHz/139/2 ≈ 179.9kHz
        check_lock(32'd180_000, 8);

        // 汇总
        if (errors == 0)
            $display("\n==== ALL TESTS PASS ====");
        else
            $display("\n==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule
