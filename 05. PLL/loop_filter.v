`timescale 1ns/1ps
//================================================================
// Loop Filter - 环路滤波器 (PI Controller)
// 实现二阶环，提供比例+积分控制
// 包含积分饱和保护和平滑输出
//================================================================
module loop_filter(
    input  wire        clk,
    input  wire        reset,
    input  wire        phase_val,  // 相位有效信号
    input  wire signed [15:0] phase_error,
    output reg         locked,    // 锁定指示
    output reg  [15:0] freq_control  // 输出给NCO的频率控制字
);

    // 参数配置
    // 对于50MHz系统时钟，200kHz对应控制字:
    // BASE = (200e3 / 50e6) * 2^32 = 17179.86496 ≈ 17180
    // 使用16位输出: BASE_16 = BASE / 2^16 ≈ 262
    parameter BASE_FREQ = 32'd17180;     // 目标频率对应的32位累加器增量
    parameter BASE      = 16'd262;        // 目标频率对应的16位输出
    parameter Kp        = 16'd80;         // 比例增益 (0.00122 * 2^16)
    parameter Ki        = 16'd5;          // 积分增益 (更小的积分增益保证稳定性)
    
    // 积分器饱和限制
    parameter I_MAX    = 16'd10000;       // 积分上限
    parameter I_MIN    = -16'd10000;      // 积分下限
    parameter OUT_MAX  = 16'd500;         // 输出上限
    parameter OUT_MIN  = -16'd500;        // 输出下限
    
    // 锁定检测参数
    parameter LOCK_THRESHOLD = 16'd50;    // 误差阈值
    parameter LOCK_CYCLES    = 16'd1000;  // 稳定周期数
    
    // 积分器
    reg signed [31:0] integral;
    reg signed [15:0] prop_term;
    reg signed [15:0] integral_term;
    
    // 锁定检测
    reg [15:0] lock_counter;
    reg signed [15:0] error_sum;
    
    // 输出饱和
    wire signed [15:0] raw_output;
    wire signed [31:0] raw_integral;
    
    // 计算积分饱和
    assign raw_integral = integral + (phase_error * Ki);
    
    // 比例项
    always @(*) begin
        prop_term = (phase_error * Kp) >>> 8;  // 右移8位相当于除以256
    end
    
    // 积分项处理(带饱和)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            integral <= {16'd0, BASE_FREQ[31:16]};  // 初始值设为BASE
            integral_term <= BASE;
        end else begin
            // 积分累加
            if (phase_val) begin
                if (raw_integral > {1'b0, I_MAX, 16'd0}) begin
                    integral <= {1'b0, I_MAX, 16'd0};
                end else if (raw_integral < {1'b1, I_MIN, 16'd0}) begin
                    integral <= {1'b1, I_MIN, 16'd0};
                end else begin
                    integral <= raw_integral;
                end
            end
            integral_term <= integral[31:16];
        end
    end
    
    // 原始输出计算
    assign raw_output = BASE + prop_term + integral_term;
    
    // 输出饱和处理
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            freq_control <= BASE;
            locked       <= 1'b0;
            lock_counter <= 16'd0;
            error_sum    <= 16'd0;
        end else begin
            // 饱和输出
            if (raw_output > OUT_MAX)
                freq_control <= OUT_MAX;
            else if (raw_output < OUT_MIN)
                freq_control <= OUT_MIN;
            else
                freq_control <= raw_output[15:0];
            
            // 锁定检测
            error_sum <= error_sum + phase_error;
            
            if (phase_val && (phase_error[14:0] < LOCK_THRESHOLD) && 
                (phase_error[14:0] > -LOCK_THRESHOLD)) begin
                if (lock_counter < LOCK_CYCLES)
                    lock_counter <= lock_counter + 1'b1;
            end else begin
                lock_counter <= 16'd0;
            end
            
            locked <= (lock_counter >= LOCK_CYCLES);
        end
    end

endmodule
