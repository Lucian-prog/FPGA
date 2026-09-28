`timescale 1ns/1ps
//================================================================
// nco - 数控振荡器（重写版）
// 原理：32 位相位累加器，16 位频率字 FTW 左移 16 位对齐累加，
//       有效相位取高 16 位，输出频率 fout = FTW / 2^16 * fclk
//       （FTW=262 @ 50MHz → 199.9kHz）
//       占空比由有效相位高 8 位（phase_acc[31:24]）与 duty_cycle 比较：
//         duty_cycle = 128（默认）→ 50% 方波
// 原版缺陷一：占空比误用 phase_acc[31:8]（24 位）与 0~255 比较，
//             输出恒为高电平、环路反馈断裂
// 原版缺陷二：FTW 零扩展加到低 16 位，但 BASE 按 2^16 语义取值，
//             实际输出频率差了 2^16 倍（约 3Hz）
//================================================================
module nco(
    input  wire        clk,          // 系统时钟
    input  wire        reset,        // 异步复位，高有效
    input  wire [15:0] freq_control, // 频率控制字 FTW（无符号）
    input  wire [7:0]  duty_cycle,   // 占空比 0~255（128 = 50%）
    output reg         B,            // 输出时钟
    output wire [31:0] phase_out     // 相位累加器（调试用）
);

    reg [31:0] phase_acc;

    assign phase_out = phase_acc;

    // 有效相位（高 16 位）的高 8 位：一个输出周期内 0~255 回绕
    wire [7:0] phase_hi = phase_acc[31:24];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            phase_acc <= 32'd0;
            B         <= 1'b0;
        end else begin
            // FTW 左移 16 位对齐：fout = FTW/2^16 * fclk
            phase_acc <= phase_acc + {freq_control, 16'd0};
            // 与上一拍相位比较后打拍输出，保证 B 为干净寄存器输出
            B <= (phase_hi < duty_cycle);
        end
    end

endmodule
