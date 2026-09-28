module i2s_receive (
    input clk_50m,
    input rst_n,  //复位信号
    input [3:0] data,  //数据输入口0-3

    output clk_ws,//帧时钟
    output clk_3m,//基准3.072M时钟,实际肯定没那么准
    output reg [23:0] L_audio_1,
    output reg [23:0] R_audio_2,
    output reg [23:0] L_audio_3,
    output reg [23:0] R_audio_4,
    output reg [23:0] L_audio_5,
    output reg [23:0] R_audio_6,
    output reg [23:0] R_audio_7,        //新增：中央右声道麦克风 mic_6
    output reg finished_left,           //左声道采集完成
    output reg finished_right           //右声道采集完成
);

//0.clk_ws下降沿采集
reg ws_d0,ws_d1;
always @(posedge clk_3m or negedge rst_n) begin
    if (!rst_n) begin
        ws_d0 <= 1'b0;
        ws_d1 <= 1'b0;
    end
    else begin
        ws_d1 <= clk_ws;
        ws_d0 <= ws_d1;//d0为旧，d1为新
    end
end
wire neg_clk_ws;
assign neg_clk_ws = ws_d0 & (~ws_d1);

//1.时钟构建
clkdiv #(
    .WIDTH(4),
    .N(17)
)clk27mTo3m(
    .clk(clk_50m),
    .rst_n(rst_n),

    .clkout(clk_3m)
);//clk_3m是clk_27m的9分频后结果
clkdiv #(
    .WIDTH(7),
    .N(64)
)clk3mTows(
    .clk(clk_3m),
    .rst_n(rst_n),

    .clkout(clk_ws)
);//clk_ws是clk_3m的64分频后结果，下降沿对齐

//2.计数器
reg [5:0] b_cnt;//数到64自动溢出
always @(posedge clk_3m or negedge rst_n) begin
    if (!rst_n) begin
        b_cnt <= 1'b0;
    end
    else if(neg_clk_ws)
        b_cnt <= 1'b0;
    else
        b_cnt <= b_cnt + 1'b1;
end

//3.取数
reg [31:0] L_data_1;
reg [31:0] R_data_2;
reg [31:0] L_data_3;
reg [31:0] R_data_4;
reg [31:0] L_data_5;
reg [31:0] R_data_6;
reg [31:0] R_data_7;  //新增：中央右声道
always @(posedge clk_3m or negedge rst_n) begin
    if (!rst_n) begin
        L_data_1 <= 32'd0;
        R_data_2 <= 32'd0;
        L_data_3 <= 32'd0;
        R_data_4 <= 32'd0;
        L_data_5 <= 32'd0;
        R_data_6 <= 32'd0;
        R_data_7 <= 32'd0;  //新增
    end
    else if(b_cnt >= 6'd1 && b_cnt <= 6'd32) begin
        L_data_1[32-b_cnt] <= data[0];
        L_data_3[32-b_cnt] <= data[1];
        L_data_5[32-b_cnt] <= data[2];
    end
    else if(b_cnt >= 6'd33 && b_cnt <= 6'd63) begin
        R_data_2[64-b_cnt] <= data[0];
        R_data_4[64-b_cnt] <= data[1];
        R_data_6[64-b_cnt] <= data[2];
        R_data_7[64-b_cnt] <= data[3];  //新增：采集data[3]
    end
end

//4.赋值并给出信号
always @(posedge clk_3m or negedge rst_n) begin
    if (!rst_n) begin
        L_audio_1 <= 24'd0;
        R_audio_2 <= 24'd0;
        L_audio_3 <= 24'd0;
        R_audio_4 <= 24'd0;
        L_audio_5 <= 24'd0;
        R_audio_6 <= 24'd0;
        R_audio_7 <= 24'd0;  //新增
        finished_left <= 1'b0;
        finished_right <= 1'b0;
    end
   else if(b_cnt == 6'd33) begin
        L_audio_1 <= L_data_1[31:8];
        L_audio_3 <= L_data_3[31:8];
        L_audio_5 <= L_data_5[31:8];
        finished_left <= 1'b1;
    end
    else if(b_cnt == 6'd0) begin
        R_audio_2 <= R_data_2[31:8];
        R_audio_4 <= R_data_4[31:8];
        R_audio_6 <= R_data_6[31:8];
        R_audio_7 <= R_data_7[31:8];  //新增：输出mic_6数据
        finished_right <= 1'b1;
    end
    else begin
        finished_left <= 1'b0;
        finished_right <= 1'b0;
    end
end

endmodule //i2s_receive
