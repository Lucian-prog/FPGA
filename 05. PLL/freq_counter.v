`timescale 1ns/1ps
//================================================================
// freq_counter - 频率计数器（重写版）
// 原理：固定系统时钟窗口内对被测信号上升沿计数，
//       f = sig_cnt * fclk / win_cnt（64 位中间量，杜绝 32 位溢出）
//       原版乘法在 32 位内完成，2 万 × 5 千万 ≈ 10^12 直接溢出
// 注：除法器仅仿真/低速率场景可综合，高速场景可换移位相减近似
//================================================================
module freq_counter(
    input  wire        clk,        // 系统时钟 50MHz
    input  wire        reset,      // 异步复位，高有效
    input  wire        B,          // 被测信号（PLL 输出）
    output reg  [31:0] freq_out,   // 测量频率（Hz）
    output reg         freq_valid  // 测量有效脉冲（每窗口一次）
);

    parameter SYS_CLK_FREQ = 32'd50_000_000; // 系统时钟频率（Hz）
    parameter MEAS_CYCLES  = 32'd5_000_000;  // 测量窗口（clk 数），100ms @ 50MHz
                                             // 仿真时可缩小以缩短运行时间

    // 输入同步与边沿检测（3 级同步，兼容被测信号来自异步域的场景）
    reg [2:0] b_sync;
    reg       b_prev;
    wire      b_rise = ~b_prev & b_sync[2];

    // 窗口计数与信号沿计数
    reg [31:0] win_cnt;
    reg [31:0] sig_cnt;

    // 64 位乘积（关键：位宽扩展到 64 位再除法）
    wire [63:0] mul = sig_cnt * SYS_CLK_FREQ;

    reg [1:0] state;
    localparam IDLE = 2'b00;
    localparam COUNT = 2'b01;
    localparam CALC  = 2'b10;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            b_sync     <= 3'b000;
            b_prev     <= 1'b0;
            win_cnt    <= 32'd0;
            sig_cnt    <= 32'd0;
            freq_out   <= 32'd0;
            freq_valid <= 1'b0;
            state      <= IDLE;
        end else begin
            b_sync <= {b_sync[1:0], B};
            b_prev <= b_sync[2];
            freq_valid <= 1'b0;

            case (state)
                IDLE: begin
                    win_cnt <= 32'd0;
                    sig_cnt <= 32'd0;
                    state   <= COUNT;
                end

                COUNT: begin
                    win_cnt <= win_cnt + 32'd1;
                    if (b_rise)
                        sig_cnt <= sig_cnt + 32'd1;
                    if (win_cnt >= MEAS_CYCLES - 32'd1)
                        state <= CALC;
                end

                CALC: begin
                    // f = sig_cnt * fclk / win_cnt（mul 已为 64 位，不溢出）
                    if (win_cnt > 32'd0)
                        freq_out <= mul / win_cnt;
                    freq_valid <= 1'b1;
                    state      <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
