`timescale 1ns/1ps
//================================================================
// phase_detector - 频相联合检测器 PFD（重写版，三态电荷泵语义）
// 原理：对 A/B 上升沿做事件配对，输出两沿间隔（clk 数）为误差：
//         A↑ 先到 → B 滞后，误差 = +(A↑→B↑ 间隔)
//         B↑ 先到 → B 超前，误差 = -(B↑→A↑ 间隔)
//         同拍到  → 误差 = 0
// 频率捕获：频差大时误差单向饱和偏移（而非线性鉴相器的锯齿混叠），
//           积分项持续单向积累，自动扫频入锁
// 原版问题：仅 ±100 两档判决，等效 1-bit 量化，环路无法平滑收敛
//================================================================
module phase_detector(
    input  wire        clk,          // 系统时钟（50MHz）
    input  wire        reset,        // 异步复位，高有效
    input  wire        A,            // 参考输入（180~240kHz，与 clk 异步）
    input  wire        B,            // NCO 反馈输出（同属 clk 域）
    output reg  signed [15:0] phase_error, // 相位误差（单位：clk 周期数）
    output reg         error_valid   // 误差有效脉冲（每次沿配对更新一次）
);

    // A 输入两级同步，避免亚稳态
    reg A_sync1, A_sync2, A_prev;
    // B 打拍取沿（B 与 clk 同源，无需多级同步）
    reg B_d;

    wire a_rise = ~A_prev & A_sync2;
    wire b_rise = ~B_d    & B;

    // 沿配对标志：等待对方的沿
    reg a_wait, b_wait;
    // 沿间隔计数（16 位饱和，正常 A 周期 ~250 clk 不会计满）
    reg [15:0] evt_cnt;

    // 频率捕获尖峰幅值（略大于最大 A 周期 278 clk @ 180kHz）
    localparam signed [15:0] SLIP_ERR = 16'sd300;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            A_sync1     <= 1'b0;
            A_sync2     <= 1'b0;
            A_prev      <= 1'b0;
            B_d         <= 1'b0;
            a_wait      <= 1'b0;
            b_wait      <= 1'b0;
            evt_cnt     <= 16'd0;
            phase_error <= 16'sd0;
            error_valid <= 1'b0;
        end else begin
            A_sync1 <= A;
            A_sync2 <= A_sync1;
            A_prev  <= A_sync2;
            B_d     <= B;
            error_valid <= 1'b0;

            // 沿间隔计数（防溢出停表）
            if (&evt_cnt == 1'b0)
                evt_cnt <= evt_cnt + 16'd1;

            if (a_rise && b_rise) begin
                // 两沿同拍：已对齐
                phase_error <= 16'sd0;
                error_valid <= 1'b1;
                a_wait      <= 1'b0;
                b_wait      <= 1'b0;
                evt_cnt     <= 16'd0;
            end else if (a_rise) begin
                if (b_wait) begin
                    // B 沿先到：B 超前，误差为负（B→A 间隔）
                    phase_error <= -$signed({1'b0, evt_cnt});
                    error_valid <= 1'b1;
                    b_wait      <= 1'b0;
                end else if (a_wait) begin
                    // 等待 B 期间又见 A 沿：B 滞后已超一个 A 周期，
                    // 输出饱和正误差（频率捕获尖峰），继续等待 B
                    phase_error <= SLIP_ERR;
                    error_valid <= 1'b1;
                    evt_cnt     <= 16'd0;
                end else begin
                    a_wait <= 1'b1;          // A 先到，等待 B
                end
                evt_cnt <= 16'd0;
            end else if (b_rise) begin
                if (a_wait) begin
                    // A 沿先到：B 滞后，误差为正（A→B 间隔）
                    phase_error <= $signed({1'b0, evt_cnt});
                    error_valid <= 1'b1;
                    a_wait      <= 1'b0;
                end else if (b_wait) begin
                    // 等待 A 期间又见 B 沿：B 超前已超一个 A 周期，
                    // 输出饱和负误差（频率捕获尖峰），继续等待 A
                    phase_error <= -SLIP_ERR;
                    error_valid <= 1'b1;
                    evt_cnt     <= 16'd0;
                end else begin
                    b_wait <= 1'b1;          // B 先到，等待 A
                end
                evt_cnt <= 16'd0;
            end
        end
    end

endmodule
