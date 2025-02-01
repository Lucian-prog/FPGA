module loop_filter(
    input  wire clk,
    input  wire reset,
    input  wire signed [15:0] phase_error,
    output reg  [15:0] freq_control  // 输出给 NCO 的频率控制字
);
    // 参数设置：对于50MHz系统时钟，
    // 理想情况下 200kHz 对应控制字 BASE = (200e3/50e6)*65536 ≈ 262
    parameter BASE = -16'd262;
    parameter Kp   = 16'd1;   // 比例增益
    parameter Ki   = 16'd1;   // 积分增益

    // 32位积分器
    reg signed [31:0] integral;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            integral     <= 0;
            freq_control <= BASE;
        end else begin
            // 更新积分项（误差乘以积分增益）
            integral <= integral + (phase_error * Ki);
            // 输出频率控制字：基础值加上比例修正和积分修正（积分部分取高16位）
            freq_control <= BASE + (phase_error * Kp) + integral[31:16];
        end
    end
endmodule
