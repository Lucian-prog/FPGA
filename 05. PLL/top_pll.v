`timescale 1ns/1ps
//================================================================
// top_pll - PLL顶层模块
// 数字锁相环，包含:
//   - 相位检测器 (Phase Detector)
//   - 环路滤波器 (Loop Filter)  
//   - 数控振荡器 (NCO)
//   - 频率计数器 (Frequency Counter)
//================================================================
module top_pll(
    input  wire        sys_clk,    // 系统时钟（50MHz）
    input  wire        reset,      // 异步复位
    input  wire        A,          // 外部输入信号A（参考信号，200kHz~240kHz）
    output wire        B,          // PLL输出的锁定时钟
    output wire [31:0] freq,       // 频率计数器输出的频率（Hz）
    output wire        locked,     // 锁定指示
    output wire [31:0] phase_out  // NCO相位输出（调试用）
);

    // 内部信号
    wire signed [15:0] phase_error;
    wire [15:0] freq_control;
    wire phase_val;
    
    // 默认占空比50% (128 = 50%)
    parameter DEFAULT_DUTY = 8'd128;
    
    // 实例化相位检测器
    phase_detector PD (
        .clk         (sys_clk),
        .reset       (reset),
        .A           (A),
        .B           (B),
        .phase_error (phase_error)
    );
    
    // 实例化环路滤波器（PI控制器）
    loop_filter LF (
        .clk          (sys_clk),
        .reset        (reset),
        .phase_val    (1'b1),           // 持续有效
        .phase_error  (phase_error),
        .locked       (locked),
        .freq_control (freq_control)
    );
    
    // 实例化NCO
    nco NCO_inst (
        .clk          (sys_clk),
        .reset        (reset),
        .freq_control (freq_control),
        .duty_cycle   (DEFAULT_DUTY),
        .B            (B),
        .phase_out    (phase_out)
    );
    
    // 实例化频率计数器
    freq_counter FC (
        .clk        (sys_clk),
        .reset      (reset),
        .B          (B),
        .freq_out   (freq),
        .freq_valid ()  // 未使用
    );

endmodule
