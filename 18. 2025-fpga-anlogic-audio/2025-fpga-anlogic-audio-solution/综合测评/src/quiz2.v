`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2025/11/28 17:43:29
// Design Name:
// Module Name: quiz
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
module traffic_button_ctrl(
        input wire clk,
        input wire rst_n,
        input wire ped_btn,
        output reg [1:0] main_light, // 0:Green, 1:Yellow, 2:Red
        output reg [1:0] ped_light// 0:Red, 1:Green
    );
    parameter RED=2'b00;
    parameter YELLOW=2'b01;
    parameter GREEN=2'b10;
    reg [1:0] cur_state;
    reg [1:0] next_state;
    reg [3:0] cnt;
    wire interrupt;
    wire state_change;
    assign state_change=(cur_state==RED && cnt==9)||((cur_state==GREEN && cnt==9)||interrupt)||(cur_state==YELLOW && cnt==2);

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt<=0;
        end
        else if(state_change) begin
            cnt<=0;
        end
        else begin
            cnt<=cnt+1;
        end
    end



    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cur_state<=RED;
        end
        else begin
            cur_state<=next_state;
        end
    end

    reg [4:0] cool_cnt;
    reg in_cooldown;
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cool_cnt<=0;
            in_cooldown<=0;
        end
        else if(interrupt) begin  // 只在中断触发时启动冷却
            cool_cnt<=18;
            in_cooldown<=1;
        end
        else if(cool_cnt>0) begin
            cool_cnt<=cool_cnt-1;
            if(cool_cnt==1)
                in_cooldown<=0;
        end
    end

    assign interrupt=(ped_btn && !in_cooldown && cur_state==GREEN);
    always@(*) begin
        if(!rst_n) begin
            next_state=RED;
        end
        else begin
            case(cur_state)
                RED: begin
                    if(state_change) begin
                        next_state=GREEN;
                    end
                    else
                        next_state=RED;
                end
                GREEN: begin
                    if(state_change||interrupt) begin
                        next_state= YELLOW;
                    end
                    else
                        next_state=GREEN;
                end
                YELLOW: begin
                    if(state_change) begin
                        next_state=RED;
                    end
                    else
                        next_state=YELLOW;
                end
            endcase
        end
    end

    always@(*) begin
        case(cur_state)
            RED: begin
                main_light = 2;  // 红灯
                ped_light = 1;   // 行人绿灯
            end
            GREEN: begin
                main_light = 0;  // 绿灯
                ped_light = 0;   // 行人红灯
            end
            YELLOW: begin
                main_light = 1;  // 黄灯
                ped_light = 0;   // 行人红灯
            end
            default: begin
                main_light = 2;
                ped_light = 1;
            end
        endcase
    end
endmodule
