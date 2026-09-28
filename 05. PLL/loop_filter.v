`timescale 1ns/1ps
//================================================================
// loop_filter - 环路滤波器（PI 控制器，重写版）
// 结构：freq_control = BASE + Kp*e + Ki*Σe，全部有符号运算、显式饱和
//   - 误差 e 单位为 clk 周期数（配对间隔，线性区 ±半周期）
//   - freq_control 为 NCO 频率字 FTW（无符号，16 位相位语义）
//   - fout = FTW/2^16 * 50MHz，1 LSB FTW ≈ 763Hz
//   - 相位差 1 clk ≈ 频差 800Hz ≈ 1.05 LSB FTW
// 环路时序（关键）：freq_control 仅在 error_valid 时更新一次并保持，
//   每 A 周期恰好应用一次修正 —— z 域离散环模型：
//   e[k+1] = e[k] * (1 - 0.36*Kp)，Kp=1 时误差每周期衰减约 64%，
//   Ki=1/4 用于消除稳态极限环
//   （反例：若每 clk 拍都重算输出，同一误差被施加约 250 拍，
//     修正过增 250 倍，环路欠阻尼 bang-bang 振荡）
// 锁定检测：|e| 连续 LOCK_NEED 个有效周期小于阈值即判定锁定；
//           误差大幅超限立即失锁
//================================================================
module loop_filter(
    input  wire        clk,
    input  wire        reset,
    input  wire        error_valid,        // 相位误差有效脉冲
    input  wire signed [15:0] phase_error, // 相位误差（clk 周期数）
    output reg         locked,             // 锁定指示
    output reg  [15:0] freq_control        // NCO 频率控制字 FTW（无符号）
);

    // 参数配置
    parameter BASE       = 16'd262;   // 200kHz 基准：200e3/50e6*2^16 ≈ 262
    parameter KP_SHIFT   = 0;         // 比例增益 2^0
    parameter KI_SHIFT   = 2;         // 积分增益 2^-2
    parameter OUT_MAX    = 16'd1023;  // 输出上限（覆盖 180~240kHz 捕捉带）
    parameter OUT_MIN    = 16'd1;     // 输出下限（频率字恒正）
    parameter LOCK_THRESH = 16'd4;    // 锁定误差阈值（±4 clk）
    parameter LOCK_NEED   = 16'd64;   // 连续达标次数

    // 积分器（FTW 域，有符号，带饱和）
    reg signed [31:0] integral_q;
    localparam signed [31:0] INT_MAX = 32'sd2048;  // 积分限幅：覆盖捕捉带
    localparam signed [31:0] INT_MIN = -32'sd2048;

    // 比例项与积分增量（算术右移实现小增益）
    wire signed [31:0] prop_term = $signed(phase_error) >>> KP_SHIFT;
    wire signed [31:0] ki_term   = $signed(phase_error) >>> KI_SHIFT;

    // 下一拍积分值（显式有符号饱和）
    wire signed [31:0] integral_nxt = (integral_q + ki_term > INT_MAX) ? INT_MAX :
                                      (integral_q + ki_term < INT_MIN) ? INT_MIN :
                                       integral_q + ki_term;

    // 新总输出 = BASE + 比例 + 更新后积分
    wire signed [31:0] total_nxt = 32'sd0 + BASE + prop_term + integral_nxt;

    // 误差绝对值（16 位；工作范围内幅值远小于 32767，无溢出风险）
    wire [15:0] abs_e = phase_error[15] ? (~phase_error + 16'd1) : phase_error;

    // 锁定计数器
    reg [15:0] lock_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            integral_q   <= 32'sd0;
            freq_control <= BASE;
            locked       <= 1'b0;
            lock_cnt     <= 16'd0;
        end else if (error_valid) begin
            // ---- 环路每 A 周期更新一次：积分 + 输出同时刷新 ----
            integral_q   <= integral_nxt;
            if (total_nxt > OUT_MAX)
                freq_control <= OUT_MAX;
            else if (total_nxt < OUT_MIN)
                freq_control <= OUT_MIN;
            else
                freq_control <= total_nxt[15:0];

            // ---- 锁定检测（仅有效拍判定）----
            if (abs_e <= LOCK_THRESH) begin
                if (lock_cnt < LOCK_NEED)
                    lock_cnt <= lock_cnt + 16'd1;
                if (lock_cnt == LOCK_NEED - 16'd1)
                    locked <= 1'b1;               // 连续达标，判定锁定
            end else if (abs_e > (LOCK_THRESH << 3)) begin
                lock_cnt <= 16'd0;
                locked   <= 1'b0;                 // 误差大幅超限，立即失锁
            end
            // 中间区间：保持当前状态（迟滞，防止边界抖动）
        end
    end

endmodule
