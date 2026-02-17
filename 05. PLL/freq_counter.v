`timescale 1ns/1ps
//================================================================
// Frequency Counter - 频率计数器
// 使用等精度测量法，支持多种测量窗口
//================================================================
module freq_counter(
    input  wire        clk,          // 系统时钟 50MHz
    input  wire        reset,        // 异步复位
    input  wire        B,            // PLL输出时钟
    output reg  [31:0] freq_out,     // 计算出的频率(Hz)
    output reg         freq_valid    // 数据有效信号
);

    // 参数配置
    parameter SYS_CLK_FREQ = 32'd50_000_000;  // 系统时钟频率
    parameter WINDOW_TIME = 32'd100_000;      // 测量窗口(us), 默认100ms
    parameter WINDOW = SYS_CLK_FREQ / 10000;  // 窗口周期数 (5000 for 100ms)
    
    // 同步器
    reg B_sync1, B_sync2, B_sync3;
    
    // 边沿检测
    reg B_prev;
    
    // 计数器
    reg  [31:0] sys_counter;      // 系统时钟计数
    reg  [31:0] signal_counter;    // 信号边沿计数
    
    // 测量状态
    reg [1:0] state;
    localparam IDLE  = 2'b00;
    localparam COUNT = 2'b01;
    localparam CALC  = 2'b10;
    
    // 中间结果(提高精度)
    reg  [63:0] freq_raw;
    
    // 同步输入信号(3级同步减少亚稳态)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            B_sync1 <= 1'b0;
            B_sync2 <= 1'b0;
            B_sync3 <= 1'b0;
            B_prev  <= 1'b0;
        end else begin
            B_sync1 <= B;
            B_sync2 <= B_sync1;
            B_sync3 <= B_sync2;
            B_prev  <= B_sync3;
        end
    end
    
    // 状态机控制
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            sys_counter <= 32'd0;
            freq_out    <= 32'd0;
            freq_valid  <= 1'b0;
            freq_raw    <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    sys_counter   <= 32'd0;
                    signal_counter<= 32'd0;
                    freq_valid    <= 1'b0;
                    state         <= COUNT;
                end
                
                COUNT: begin
                    // 系统时钟计数器
                    sys_counter <= sys_counter + 1'b1;
                    
                    // 信号上升沿计数
                    if (~B_prev & B_sync3) begin
                        signal_counter <= signal_counter + 1'b1;
                    end
                    
                    // 达到测量窗口
                    if (sys_counter >= WINDOW - 1) begin
                        state <= CALC;
                    end
                end
                
                CALC: begin
                    // 频率计算: f = (signal_count / sys_count) * sys_clk_freq
                    // 使用64位乘法避免溢出
                    if (sys_counter > 0) begin
                        freq_raw <= ($signed(signal_counter) * $signed(SYS_CLK_FREQ)) >> 10;
                        // 右移10位相当于除以1024，作为近似处理
                        // 更精确: freq_raw = signal_counter * SYS_CLK_FREQ / sys_counter
                        freq_out <= (signal_counter * SYS_CLK_FREQ) / sys_counter;
                    end
                    freq_valid <= 1'b1;
                    state     <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
