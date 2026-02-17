`timescale 1ns/1ps
//================================================================
// Phase Detector - 相位检测器
// 使用Type-II鉴相器(JK触发器型)，检测A和B的相位差
// 输出为有符号误差：正值表示B落后于A，负值表示B超前于A
//================================================================
module phase_detector(
    input  wire        clk,        // 系统时钟（50MHz）
    input  wire        reset,      // 异步复位
    input  wire        A,          // 外部输入参考信号
    input  wire        B,          // NCO输出信号
    output reg  signed [15:0] phase_error  // 相位误差输出
);

    // 两级同步器，避免亚稳态
    reg A_sync1, A_sync2;
    reg B_sync1, B_sync2;
    
    // 边沿检测
    reg A_prev, B_prev;
    
    // 脉冲计数器，用于积分型鉴相
    reg [7:0] pulse_count;
    reg       counting;
    
    // 状态机
    localparam IDLE    = 2'b00;
    localparam COUNT   = 2'b01;
    localparam HOLD    = 2'b10;
    
    reg [1:0] state, next_state;
    
    // 同步A信号到系统时钟域
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            A_sync1 <= 1'b0;
            A_sync2 <= 1'b0;
        end else begin
            A_sync1 <= A;
            A_sync2 <= A_sync1;
        end
    end
    
    // 同步B信号到系统时钟域
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            B_sync1 <= 1'b0;
            B_sync2 <= 1'b0;
        end else begin
            B_sync1 <= B;
            B_sync2 <= B_sync1;
        end
    end
    
    // 边沿检测和状态机
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            A_prev      <= 1'b0;
            B_prev      <= 1'b0;
            pulse_count <= 8'd0;
            counting    <= 1'b0;
            state       <= IDLE;
            phase_error <= 16'sd0;
        end else begin
            A_prev <= A_sync2;
            B_prev <= B_sync2;
            
            case (state)
                IDLE: begin
                    // 检测A的上升沿开始计数
                    if (~A_prev & A_sync2) begin
                        state <= COUNT;
                        counting <= 1'b1;
                        pulse_count <= 8'd0;
                    end
                end
                
                COUNT: begin
                    if (counting) begin
                        // 在B的每个周期累加
                        if (~B_prev & B_sync2) begin
                            pulse_count <= pulse_count + 1'b1;
                        end
                        // A下降沿停止计数
                        if (A_prev & ~A_sync2) begin
                            counting <= 1'b0;
                            state <= HOLD;
                        end
                    end
                end
                
                HOLD: begin
                    // 计算误差：基于A周期内B的上升沿数量
                    // 如果B频率高于A，计数大，误差为正(B落后)
                    // 如果B频率低于A，计数小，误差为负(B超前)
                    if (pulse_count >= 8'd1) begin
                        // B周期数 >= 1，表示B频率高于或接近A
                        phase_error <= 16'sd100;  // 正向误差
                    end else begin
                        phase_error <= -16'sd100; // 负向误差
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
