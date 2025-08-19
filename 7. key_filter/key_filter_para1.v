`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  NJUPT
// Engineer: Lucian
// 
// Create Date: 2025/08/17 17:36:58
// Design Name: 
// Module Name: key_filter
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
module key_filter (
    input  wire clk,
    input  wire rst_n,
    input  wire key,
    output reg  key_p_flag,
    output reg  key_r_flag,
    output reg  key_state
);

  // 消抖时间参数 (20ms at 50MHz clock)
  localparam DEBOUNCE_TIME = 20'd1000000;
  
  reg [1:0] r_key;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_key <= 2'b11;  // 复位时初始化为按键释放状态
    end else begin
      r_key <= {r_key[0], key};
    end
  end
  wire pedge_key;
  assign pedge_key = (r_key == 2'b01);
  wire nedge_key;
  assign nedge_key = (r_key == 2'b10);

  localparam IDLE = 2'b00;
  localparam P_FILTER = 2'b01;
  localparam WAIT_R = 2'b10;
  localparam R_FILTER = 2'b11;
  reg [19:0] cnt;
  reg [ 1:0] state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      key_p_flag <= 1'b0;
      key_r_flag <= 1'b0;
      key_state <= 1'b1;  // 初始状态为按键释放
      cnt <= 20'd0;
    end else begin
      case (state)
        IDLE: begin
          key_r_flag <= 1'b0;
          cnt <= 20'd0;  // 在IDLE状态清零计数器
          if (nedge_key) state <= P_FILTER;
          else state <= IDLE;
        end
        P_FILTER:
        if ((pedge_key) && (cnt < DEBOUNCE_TIME - 1)) begin
          state <= IDLE;
          cnt <= 20'd0;  // 状态转换时清零计数器
        end else if (cnt >= DEBOUNCE_TIME - 1) begin
          state <= WAIT_R;
          key_p_flag <= 1'b1;
          key_state <= 1'b0;  // 统一使用<=操作符
          cnt <= 20'd0;  // 状态转换时清零计数器
        end else begin
          state <= P_FILTER;
          cnt <= cnt + 1'b1;
        end

        WAIT_R: begin
          key_p_flag <= 1'b0;
          cnt <= 20'd0;  // 在WAIT_R状态保持计数器清零
          if (pedge_key) state <= R_FILTER;
          else state <= WAIT_R;
        end
        R_FILTER:
        if ((nedge_key) && (cnt <= DEBOUNCE_TIME - 1)) begin
          state <= WAIT_R;
          cnt <= 20'd0;  // 状态转换时清零计数器
        end else if (cnt >= DEBOUNCE_TIME - 1) begin
          state <= IDLE;
          key_r_flag <= 1'b1;
          cnt <= 20'd0;  // 统一使用<=操作符，状态转换时清零
          key_state <= 1'b1;  // 统一使用<=操作符
        end else begin
          state <= R_FILTER;
          cnt <= cnt + 1'b1;
        end
      endcase
    end
  end

endmodule
