`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NJUPT
// Engineer: Lucian
// 
// Create Date: 2025/08/19 15:33:14
// Design Name: 
// Module Name: key_filter_para3
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module key_filter_para3 (
    input  wire        clk,          // 系统时钟
    input  wire        rst_n,        // 异步复位，低电平有效
    input  wire        key,          // 原始按键输入 (低电平为按下)

    output reg         key_p_flag,   // 按键按下标志 (单周期脉冲)
    output reg         key_r_flag,   // 按键释放标志 (单周期脉冲)
    output reg         key_state     // 消抖后的稳定按键状态 (1:释放, 0:按下)
);

// 消抖时间参数 (以50MHz时钟为例，20ms)
localparam DEBOUNCE_TIME = 20'd1_000_000;

// 状态机状态定义
localparam S_IDLE        = 2'b00;    // 空闲状态
localparam S_P_FILTER    = 2'b01;    // 按下消抖
localparam S_WAIT_R      = 2'b10;    // 等待释放
localparam S_R_FILTER    = 2'b11;    // 释放消抖

// 输入同步及边沿检测
reg  [1:0] r_key;
wire       pedge_key; // 上升沿 (释放)
wire       nedge_key; // 下降沿 (按下)

// 状态机寄存器
reg  [1:0] current_state;
reg  [1:0] next_state;

// 消抖计数器
reg  [19:0] cnt;


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) r_key <= 2'b11;
    else        r_key <= {r_key[0], key};
end

assign nedge_key = (r_key == 2'b10);
assign pedge_key = (r_key == 2'b01);

// 段一：次态逻辑 (组合逻辑) 
// 职责：只根据当前状态和输入，决定下一个状态是什么。
always @(*) begin
    // 黄金法则：为 next_state 提供默认值，防止产生latch
    next_state = current_state; 
    
    case (current_state)
        S_IDLE: begin
            if (nedge_key) begin
                next_state = S_P_FILTER;
            end
        end
        S_P_FILTER: begin
            if (pedge_key) begin // 抖动，返回IDLE
                next_state = S_IDLE;
            end else if (cnt >= DEBOUNCE_TIME - 1) begin // 消抖成功
                next_state = S_WAIT_R;
            end
        end
        S_WAIT_R: begin
            if (pedge_key) begin
                next_state = S_R_FILTER;
            end
        end
        S_R_FILTER: begin
            if (nedge_key) begin // 抖动，返回WAIT_R
                next_state = S_WAIT_R;
            end else if (cnt >= DEBOUNCE_TIME - 1) begin // 消抖成功
                next_state = S_IDLE;
            end
        end
        default: begin
            next_state = S_IDLE;
        end
    endcase
end

// 段二：状态更新 (时序逻辑) -- 状态机的“心脏”
// 职责：只在时钟沿，用 next_state 更新 current_state。

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= S_IDLE;
    end else begin
        current_state <= next_state;
    end
end


// 段三：输出与动作逻辑 (时序逻辑) -- 翻译状态图的“圆圈”和“动作”
// 职责：只根据当前状态，决定输出信号和内部寄存器(如cnt)的行为。
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_p_flag <= 1'b0;
        key_r_flag <= 1'b0;
        key_state  <= 1'b1; // 初始为释放状态
        cnt        <= 20'd0;
    end else begin
        // 默认将脉冲信号拉低，只在特定切换瞬间拉高一拍
        key_p_flag <= 1'b0;
        key_r_flag <= 1'b0;

        case (current_state)
            S_IDLE: begin
                key_state <= 1'b1;
                cnt       <= 20'd0;
            end
            S_P_FILTER: begin
                key_state <= 1'b1; // 消抖期间，稳定状态仍是“释放”
                if (pedge_key) begin
                    cnt <= 20'd0; // 抖动，计数器清零
                end else if (cnt >= DEBOUNCE_TIME - 1) begin
                    key_p_flag <= 1'b1; // 在切换前一刻，产生按下脉冲
                    cnt        <= 20'd0;
                end else begin
                    cnt <= cnt + 1'b1; // 持续计时
                end
            end
            S_WAIT_R: begin
                key_state <= 1'b0; // 稳定按下
                cnt       <= 20'd0;
            end
            S_R_FILTER: begin
                key_state <= 1'b0; // 消抖期间，稳定状态仍是“按下”
                if (nedge_key) begin
                    cnt <= 20'd0; // 抖动，计数器清零
                end else if (cnt >= DEBOUNCE_TIME - 1) begin
                    key_r_flag <= 1'b1; // 在切换前一刻，产生释放脉冲
                    cnt        <= 20'd0;
                end else begin
                    cnt <= cnt + 1'b1; // 持续计时
                end
            end
            default: begin
                key_state <= 1'b1;
                cnt       <= 20'd0;
            end
        endcase
    end
end

endmodule
