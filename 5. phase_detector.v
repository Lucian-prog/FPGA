`timescale 1ns/1ps
module phase_detector(
    input  wire clk,        // 系统时钟（50MHz）
    input  wire reset,
    input  wire A,          // 外部输入信号 A（需先同步到系统时钟域）
    input  wire B,          // NCO 输出信号 B
    output reg  signed [15:0] phase_error  // 输出误差：+1 或 -1
);
    reg A_prev;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            A_prev      <= 1'b0;
            phase_error <= 16'sd0;
        end else begin
            // 检测 A 信号的上升沿
            if (~A_prev & A) begin
                // 当 B 为低时，B 落后，输出正误差
                if (B == 1'b0)
                    phase_error <= 16'sd1;
                else
                    phase_error <= -16'sd1;
            end else begin
                phase_error <= 16'sd0;
            end
            A_prev <= A;
        end
    end
endmodule
