module top_pll(
    input  wire sys_clk,  // 系统时钟（50MHz）
    input  wire reset,
    input  wire A,        // 外部输入信号 A（预期为200kHz～240kHz）
    output wire B,        // PLL 输出的锁定时钟 B
    output wire [31:0] freq  // 频率计数器输出的 B 信号频率（Hz）
);
    wire signed [15:0] phase_error;
    wire [15:0] freq_control;

    // 实例化相位检测器
    phase_detector PD (
        .clk(clk),
        .reset(reset),
        .A(A),
        .B(B),
        .phase_error(phase_error)
    );
    
    // 实例化环路滤波器（PI 控制器）
    loop_filter LF (
        .clk(sys_clk),
        .reset(reset),
        .phase_error(phase_error),
        .freq_control(freq_control)
    );
    
    // 实例化 NCO
    nco NCO_inst (
        .clk(sys_clk),
        .reset(reset),
        .freq_control(freq_control),
        .B(B)
    );
    
    // 实例化频率计数器
    freq_counter FC (
        .clk(sys_clk),
        .reset(reset),
        .B(B),
        .freq_out(freq)
    );
endmodule
