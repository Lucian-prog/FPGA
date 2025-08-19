`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NJUPT
// Engineer: Lucian
// 
// Create Date: 2025/08/19 14:39:05
// Design Name: 
// Module Name: key_filter_para2
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


module key_filter_para2(
    input wire clk,
    input wire rst_n,
    input wire key,

    output reg key_p_flag,
    output reg key_r_flag,
    output reg key_state
    );

localparam DEBOUNCE_TIME = 20'd1_000_000;
localparam IDLE=2'b00;
localparam P_FILTER=2'b01;
localparam WAIT_R = 2'b10;
localparam R_FILTER=2'b11;

reg [1:0] r_key;
wire pedge_key;
wire nedge_key;

reg [1:0]current_state, next_state;

reg [19:0] cnt;

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
    r_key<=2'b11;
    else 
    r_key<={r_key[0],key};
end

assign pedge_key = (r_key == 2'b01);
assign nedge_key = (r_key == 2'b10);


//二段式

//段一，状态更新（时序）

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        current_state <=IDLE;
    end
    else begin
        current_state <= next_state;
    end
end


//段二，次态逻辑+输出逻辑（组合逻辑）
always @(*) begin
    
    next_state = current_state;
    key_p_flag = 1'b0;
    key_r_flag = 1'b0;
    key_state  = 1'b1; 

    case (current_state)
        IDLE: begin
            key_state = 1'b1; 
            if (nedge_key) begin
                next_state = P_FILTER;
            end
        end
        P_FILTER: begin
            key_state = 1'b1; 
            if (pedge_key) begin
                next_state = IDLE;
            end else if (cnt >= DEBOUNCE_TIME - 1) begin
                next_state = WAIT_R;
                key_p_flag = 1'b1;  
                key_state  = 1'b0;  
            end
        end
        WAIT_R: begin
            key_state = 1'b0; 
            if (pedge_key) begin
                next_state = R_FILTER;
            end
        end
        R_FILTER: begin
            key_state = 1'b0; 
            if (nedge_key) begin
                next_state = WAIT_R;
            end else if (cnt >= DEBOUNCE_TIME - 1) begin
                next_state = IDLE;
                key_r_flag = 1'b1; 
                key_state  = 1'b1; 
            end
        end
        default: begin
            next_state = IDLE;
            key_state  = 1'b1;
        end
    endcase
end

// 计数器逻辑，为了清晰，通常单独放在一个时序块中
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 20'd0;
    end else if (next_state != current_state) begin // 状态切换时清零
        cnt <= 20'd0;
    end else if (current_state == P_FILTER || current_state == R_FILTER) begin
        cnt <= cnt + 1'b1;
    end else begin
        cnt <= 20'd0;
    end
end
endmodule
