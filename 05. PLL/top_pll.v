`timescale 1ns/1ps
//================================================================
// top_pll - 数字锁相环顶层（重写版）
//   参考输入 A（180~240kHz）→ 环路锁定后输出同频方波 B
//   相位检测（线性误差）→ PI 环路滤波 → NCO → 反馈
//   接口与原版保持一致，仅内部重构
//================================================================
module top_pll #(
    parameter MEAS_CYCLES = 32'd5_000_000  // 频率计测量窗口（clk 数）
)(
    input  wire        sys_clk,    // 系统时钟（50MHz）
    input  wire        reset,      // 异步复位，高有效
    input  wire        A,          // 参考信号输入（180~240kHz）
    output wire        B,          // PLL 输出（锁定后与 A 同频同占空比）
    output wire [31:0] freq,       // 频率测量读数（Hz）
    output wire        locked,     // 锁定指示
    output wire [31:0] phase_out   // NCO 相位输出（调试用）
);

    // 输出占空比（128 = 50%）
    parameter DEFAULT_DUTY = 8'd128;

    // 内部互连
    wire signed [15:0] phase_error;
    wire        error_valid;
    wire [15:0] freq_control;

    // 相位检测器：线性相位误差，每 A 周期更新一次
    phase_detector PD (
        .clk         (sys_clk),
        .reset       (reset),
        .A           (A),
        .B           (B),
        .phase_error (phase_error),
        .error_valid (error_valid)
    );

    // 环路滤波器（PI）：BASE + Kp*e + Ki*Σe，带饱和与锁定检测
    loop_filter LF (
        .clk          (sys_clk),
        .reset        (reset),
        .error_valid  (error_valid),
        .phase_error  (phase_error),
        .locked       (locked),
        .freq_control (freq_control)
    );

    // NCO：fout = FTW/2^16 * 50MHz，占空比可调
    nco NCO_inst (
        .clk          (sys_clk),
        .reset        (reset),
        .freq_control (freq_control),
        .duty_cycle   (DEFAULT_DUTY),
        .B            (B),
        .phase_out    (phase_out)
    );

    // 频率计数器：等窗口计数法测 B 频率
    freq_counter #(
        .MEAS_CYCLES (MEAS_CYCLES)
    ) FC (
        .clk        (sys_clk),
        .reset      (reset),
        .B          (B),
        .freq_out   (freq),
        .freq_valid ()           // 顶层未使用，TB 可层次引用
    );

endmodule
