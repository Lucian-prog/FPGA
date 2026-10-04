module mic_serial (
    input clk,                 // Clock
    input rst_n,
    input rst_dsp,
    output mic_clk,
    output mic_ws,
    input [3:0] mic_so,
    output signed[23:0] mic_0,
    output signed[23:0] mic_1,
    output signed[23:0] mic_2,
    output signed[23:0] mic_3,
    output signed[23:0] mic_4,
    output signed[23:0] mic_5,
    output signed[23:0] mic_6,
    output finished_left1,
    output finished_right1,
    output reg start,
    // AUDIO_PROCESS 专用：clk 域内的一份完整左右声道样本。
    output reg signed [15:0] frame_l,
    output reg signed [15:0] frame_r,
    output reg frame_valid
);
    
wire signed[23:0] mic_data_left1;
wire signed[23:0] mic_data_right1;
wire signed[23:0] mic_data_left2;
wire signed[23:0] mic_data_right2;
wire signed[23:0] mic_data_left3;
wire signed[23:0] mic_data_right3;
wire signed[23:0] mic_data_right4;  // mic_6: 中央右声道

reg  signed[23:0] mic_data_left1_d0;
reg  signed[23:0] mic_data_right1_d0;
reg  signed[23:0] mic_data_left2_d0;
reg  signed[23:0] mic_data_right2_d0;
reg  signed[23:0] mic_data_left3_d0;
reg  signed[23:0] mic_data_right3_d0;
reg  signed[23:0] mic_data_right4_d0;

reg  signed[23:0] mic_data_left1_d1;
reg  signed[23:0] mic_data_right1_d1;
reg  signed[23:0] mic_data_left2_d1;
reg  signed[23:0] mic_data_right2_d1;
reg  signed[23:0] mic_data_left3_d1;
reg  signed[23:0] mic_data_right3_d1;
reg  signed[23:0] mic_data_right4_d1;

reg  signed[23:0] mic_data_left1_d2;
reg  signed[23:0] mic_data_right1_d2;
reg  signed[23:0] mic_data_left2_d2;
reg  signed[23:0] mic_data_right2_d2;
reg  signed[23:0] mic_data_left3_d2;
reg  signed[23:0] mic_data_right3_d2;
reg  signed[23:0] mic_data_right4_d2;

assign mic_0 = mic_data_right1_d2;
assign mic_1 = mic_data_left1_d2;
assign mic_2 = mic_data_right2_d2;
assign mic_3 = mic_data_left2_d2;
assign mic_4 = mic_data_right3_d2;
assign mic_5 = mic_data_left3_d2;
assign mic_6 = mic_data_right4_d2;

reg [10:0] cnt_start; 

// 接收器完成标志保持一个 BCLK；同步其下降沿后，PCM 已稳定至少
// 一个 BCLK。这里使用稳定数据 + 延迟控制的 bundled-data 传输，
// 不是逐位双触发器同步。前提：BCLK 周期足够目标域捕获完成脉冲，
// 且从 PCM 源寄存器到捕获寄存器的数据路径短于该稳定窗口。
// 当前约 16 个 clk 周期/BCLK；实现时仍须约束和检查这条数据路径。
(* ASYNC_REG = "TRUE" *) reg [1:0] frame_reset_sync;
wire frame_rst_n = frame_reset_sync[1];
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) frame_reset_sync <= 2'b00;
  else frame_reset_sync <= {frame_reset_sync[0], 1'b1};
end

(* ASYNC_REG = "TRUE" *) reg [1:0] left_sync, right_sync, ws_sync;
reg left_prev, right_prev, ws_prev;
wire left_complete = left_prev && !left_sync[1];
wire right_complete = right_prev && !right_sync[1];
wire frame_boundary = ws_prev && !ws_sync[1];
reg frame_armed, left_pending;
reg signed [15:0] left_hold;

always @(posedge clk or negedge frame_rst_n) begin
  if (!frame_rst_n) begin
    left_sync <= 0;
    right_sync <= 0;
    ws_sync <= 0;
    left_prev <= 0;
    right_prev <= 0;
    ws_prev <= 0;
  end else begin
    left_sync <= {left_sync[0], finished_left1};
    right_sync <= {right_sync[0], finished_right1};
    ws_sync <= {ws_sync[0], mic_ws};
    left_prev <= left_sync[1];
    right_prev <= right_sync[1];
    ws_prev <= ws_sync[1];
  end
end

always @(posedge clk or negedge frame_rst_n) begin
  if (!frame_rst_n) begin
    frame_armed <= 1'b0;
    left_pending <= 1'b0;
    left_hold <= 0;
    frame_l <= 0;
    frame_r <= 0;
    frame_valid <= 1'b0;
  end else begin
    frame_valid <= 1'b0;
    // 复位后先观察真实 WS 下降沿，丢弃未收齐的启动半帧。
    if (frame_boundary) frame_armed <= 1'b1;
    if (left_complete && frame_armed) begin
      left_hold <= mic_data_left1[23:8];
      left_pending <= 1'b1;
    end
    if (right_complete && left_pending) begin
      frame_l <= left_hold;
      frame_r <= mic_data_right1[23:8];
      frame_valid <= 1'b1;
      left_pending <= 1'b0;
    end
  end
end

always @(posedge clk or negedge rst_dsp) begin
    if (!rst_dsp) begin
        mic_data_left1_d0  <= 0;
        mic_data_right1_d0 <= 0;
        mic_data_left1_d1  <= 0;
        mic_data_right1_d1 <= 0;
        mic_data_left1_d2  <= 0;
        mic_data_right1_d2 <= 0;
        mic_data_left2_d0  <= 0;
        mic_data_left2_d1  <= 0;
        mic_data_left2_d2  <= 0;
        mic_data_right2_d0 <= 0;
        mic_data_left3_d0  <= 0;
        mic_data_right3_d0 <= 0;
        mic_data_right2_d1 <= 0;
        mic_data_left3_d1  <= 0;
        mic_data_right3_d1 <= 0;
        mic_data_right2_d2 <= 0;
        mic_data_right3_d0 <= 0;
        mic_data_right3_d2 <= 0;
        mic_data_right4_d0 <= 0;
        mic_data_right4_d1 <= 0;
        mic_data_right4_d2 <= 0;  // 新增：mic_6延迟寄存器复位
        cnt_start <= 0;
    end
    else if (finished_left1) begin
        cnt_start <= cnt_start + 11'd1;
        
        mic_data_left1_d0 <= mic_data_left1;
        mic_data_left1_d1 <= mic_data_left1_d0;
        mic_data_left1_d2 <= mic_data_left1_d1;

        mic_data_left2_d0 <= mic_data_left2;
        mic_data_left2_d1 <= mic_data_left2_d0;
        mic_data_left2_d2 <= mic_data_left2_d1;

        mic_data_left3_d0 <= mic_data_left3;
        mic_data_left3_d1 <= mic_data_left3_d0;
        mic_data_left3_d2 <= mic_data_left3_d1;
    end
    else if (finished_right1) begin
        mic_data_right1_d0 <= mic_data_right1;
        mic_data_right1_d1 <= mic_data_right1_d0;
        mic_data_right1_d2 <= mic_data_right1_d1;

        mic_data_right2_d0 <= mic_data_right2;
        mic_data_right2_d1 <= mic_data_right2_d0;
        mic_data_right2_d2 <= mic_data_right2_d1;

        mic_data_right3_d0 <= mic_data_right3;
        mic_data_right3_d1 <= mic_data_right3_d0;
        mic_data_right3_d2 <= mic_data_right3_d1;

        mic_data_right4_d0 <= mic_data_right4;  // 新增：mic_6延迟链
        mic_data_right4_d1 <= mic_data_right4_d0;
        mic_data_right4_d2 <= mic_data_right4_d1;
    end
end
            
            
            
always@(posedge clk or negedge rst_dsp) begin
    if (!rst_dsp) begin
        start <= 0;
    end
    else if (finished_left1) begin
        if (cnt_start == 11'd3)
            start <= 1;
    end
end  
                    
i2s_receive microphoneIns(
    //input
    .clk_50m(clk),
    .rst_n(rst_n),
    .data(mic_so),
    //output
    .clk_ws(mic_ws),
    .clk_3m(mic_clk),
    .L_audio_1(mic_data_left1),
    .R_audio_2(mic_data_right1),
    .L_audio_3(mic_data_left2),
    .R_audio_4(mic_data_right2),
    .L_audio_5(mic_data_left3),
    .R_audio_6(mic_data_right3),
    .R_audio_7(mic_data_right4),  // 新增：连接mic_6
    .finished_left(finished_left1),
    .finished_right(finished_right1)
);                  

endmodule
