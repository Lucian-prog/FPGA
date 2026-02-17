`timescale 1ns/1ps
//================================================================
// NCO (Numerical Controlled Oscillator) - 数控振荡器
// 基于相位累加器实现，支持可调占空比和相位输出
//================================================================
module nco(
    input  wire        clk,          // 系统时钟
    input  wire        reset,        // 异步复位
    input  wire [15:0] freq_control, // 频率控制字
    input  wire [7:0]  duty_cycle,   // 占空比 (0-255, 128=50%)
    output reg         B,            // 输出时钟
    output wire [31:0] phase_out     // 相位输出(用于调试)
);

    // 相位累加器
    reg [31:0] phase_acc;
    
    // 占空比比较值
    reg [31:0] duty_thresh;
    
    // 同步fifo用于输出(减少毛刺)
    reg B_raw, B_sync1, B_sync2;
    
    // 输出相位
    assign phase_out = phase_acc;
    
    // 占空比阈值计算
    always @(*) begin
        // 将相位范围映射到占空比
        // 相位累加器最高位翻转一次为一个完整周期
        duty_thresh = {16'd0, duty_cycle, 8'd0};  // duty_cycle * 256
    end
    
    // 相位累加
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            phase_acc <= 32'd0;
            B_raw     <= 1'b0;
            B_sync1   <= 1'b0;
            B_sync2   <= 1'b0;
        end else begin
            // 累加频率控制字
            phase_acc <= phase_acc + {16'd0, freq_control};
            
            // 原始时钟输出(基于相位MSB)
            B_raw <= phase_acc[31];
            
            // 两级同步，减少亚稳态
            B_sync1 <= B_raw;
            B_sync2 <= B_sync1;
            
            // 占空比调节版本
            if (phase_acc[31:8] < duty_thresh[31:8])
                B <= 1'b1;
            else
                B <= 1'b0;
        end
    end
    
    // 可选：直接输出(50%占空比)
    // 解除下面注释使用50%占空比输出
    // always @(*) B = phase_acc[31];

endmodule
