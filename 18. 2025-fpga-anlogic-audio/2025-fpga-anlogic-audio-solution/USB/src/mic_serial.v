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
    output reg start
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