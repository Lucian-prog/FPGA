module AUDIO_PROCESS(
    input rst_n,
    input signed [15:0] audio_r,
    input signed [15:0] audio_l,
    input clk,                    // 统一 50 MHz 系统时钟
    input in_valid,               // 一份完整的左右声道样本
    output in_ready,
    output reg out_valid,
    input wire sw0,
    input wire sw1,
    input wire sw2,
    input wire sw3,
    input wire sw4,
    input wire sw5,
    input signed [15:0] audio_ref,
    output reg signed [15:0] o_audio_r,
    output reg signed [15:0] o_audio_l,
    output tVAD
);

wire signed [15:0] dout_l0,dout_r0,dout_l1,dout_r1,dout_l2,dout_r2;
wire signed [15:0] dout_ch_l,dout_ch_r;
wire signed [15:0] dout_voice_l, dout_voice_r;
wire signed [15:0] dout_atmo_l, dout_atmo_r;  // 氛围感增强输出
wire signed [15:0] dout_atmo_l0, dout_atmo_r0;  // 氛围感增强中间级
wire signed [15:0] agc_l,agc_r;
wire signed [15:0] agc_out_l, agc_out_r;

// 异步置位复位、同步释放；不使用采样脉冲作为时钟。
(* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;
wire run_rst_n = reset_sync[1];
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) reset_sync <= 2'b00;
  else reset_sync <= {reset_sync[0], 1'b1};
end

// 拨码开关是独立控制位；同步后在接收一帧时锁存本帧模式。
// 这不是多位配置总线握手，也不提供机械开关消抖。
(* ASYNC_REG = "TRUE" *) reg [5:0] sw_meta, sw_sync;
always @(posedge clk or negedge run_rst_n) begin
  if (!run_rst_n) begin
    sw_meta <= 6'b0;
    sw_sync <= 6'b0;
  end else begin
    sw_meta <= {sw5, sw4, sw3, sw2, sw1, sw0};
    sw_sync <= sw_meta;
  end
end

localparam IDLE = 2'd0, LAUNCH = 2'd1, WAIT_RESULT = 2'd2;
reg [1:0] state;
reg [5:0] mode_q;
reg signed [15:0] sample_l, sample_r, ref_q;
wire sample_en = (state == LAUNCH);
wire [13:0] filter_done;
wire agc_done_l, agc_done_r;
reg agc_seen_l, agc_seen_r;
assign in_ready = run_rst_n && (state == IDLE);

always @(posedge clk or negedge run_rst_n) begin
  if (!run_rst_n) begin
    state <= IDLE;
    mode_q <= 6'b0;
    sample_l <= 16'sd0;
    sample_r <= 16'sd0;
    ref_q <= 16'sd0;
    o_audio_l <= 16'sd0;
    o_audio_r <= 16'sd0;
    out_valid <= 1'b0;
    agc_seen_l <= 1'b0;
    agc_seen_r <= 1'b0;
  end else begin
    out_valid <= 1'b0;
    case (state)
      IDLE: if (in_valid) begin
        sample_l <= audio_l;
        sample_r <= audio_r;
        ref_q <= audio_ref;
        mode_q <= sw_sync;
        agc_seen_l <= 1'b0;
        agc_seen_r <= 1'b0;
        state <= LAUNCH;
      end
      // 所有 IIR/AGC 同拍取样，保留原设计读取前级旧输出的递推关系。
      LAUNCH: state <= WAIT_RESULT;
      WAIT_RESULT: begin
        if (agc_done_l) agc_seen_l <= 1'b1;
        if (agc_done_r) agc_seen_r <= 1'b1;
        if ((&filter_done) && (agc_seen_l || agc_done_l) &&
                             (agc_seen_r || agc_done_r)) begin
          o_audio_l <= mode_q[0] ? agc_out_l : agc_l;
          o_audio_r <= mode_q[0] ? agc_out_r : agc_r;
          out_valid <= 1'b1;
          state <= IDLE;
        end
      end
      default: state <= IDLE;
    endcase
  end
end

audio_iir_step #(.K1(16'sd1980), .K2(16'sd959), .K3(16'sd1026)) u_iir_0(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[0]),
    .rst_n(run_rst_n),
    .din(sample_l),
    .dout(dout_l1)
);
audio_iir_step #(.K1(16'sd1690), .K2(16'sd741), .K3(16'sd1026)) u_iir_1(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[1]),
    .rst_n(run_rst_n),
    .din(dout_l1),
    .dout(dout_l2)
);

audio_iir_step #(.K1(16'sd1980), .K2(16'sd959), .K3(16'sd1026)) u_iir_2(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[2]),
    .rst_n(run_rst_n),
    .din(sample_r),
    .dout(dout_r1)
);
audio_iir_step #(.K1(16'sd1690), .K2(16'sd741), .K3(16'sd1026)) u_iir_3(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[3]),
    .rst_n(run_rst_n),
    .din(dout_r1),
    .dout(dout_r2)
);
//中心频点300Hz
audio_iir_step #(.STATE_W(42), .PRODUCT_W(42), .FEEDBACK_DIV(4096), .OUTPUT_DIV(65536), .K1(16'sd8020), .K2(16'sd3932), .K3(16'sd1322)) u_iir_4(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[4]),
    .rst_n(run_rst_n),
    .din(sample_l),
    .dout(dout_ch_l)
);
audio_iir_step #(.STATE_W(42), .PRODUCT_W(42), .FEEDBACK_DIV(4096), .OUTPUT_DIV(65536), .K1(16'sd8020), .K2(16'sd3932), .K3(16'sd1322)) u_iir_5(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[5]),
    .rst_n(run_rst_n),
    .din(sample_r),
    .dout(dout_ch_r)
);

// 人声增强EQ（2000Hz中心频点）- 左声道两级级联
audio_iir_step #(.K1(16'sd1906), .K2(16'sd913), .K3(16'sd920)) u_iir_6(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[6]),
    .rst_n(run_rst_n),
    .din(sample_l),
    .dout(dout_l0)
);

audio_iir_step #(.K1(16'sd1720), .K2(16'sd814), .K3(16'sd920)) u_iir_7(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[7]),
    .rst_n(run_rst_n),
    .din(dout_l0),
    .dout(dout_voice_l)
);

// 人声增强EQ（2000Hz中心频点）- 右声道两级级联
audio_iir_step #(.K1(16'sd1906), .K2(16'sd913), .K3(16'sd920)) u_iir_8(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[8]),
    .rst_n(run_rst_n),
    .din(sample_r),
    .dout(dout_r0)
);

audio_iir_step #(.K1(16'sd1720), .K2(16'sd814), .K3(16'sd920)) u_iir_9(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[9]),
    .rst_n(run_rst_n),
    .din(dout_r0),
    .dout(dout_voice_r)
);

// 氛围感增强EQ（4000Hz中心频点）- 左声道两级级联
audio_iir_step #(.K1(16'sd1773), .K2(16'sd855), .K3(16'sd1252)) u_iir_10(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[10]),
    .rst_n(run_rst_n),
    .din(sample_l),
    .dout(dout_atmo_l0)
);

audio_iir_step #(.K1(16'sd1479), .K2(16'sd756), .K3(16'sd1252)) u_iir_11(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[11]),
    .rst_n(run_rst_n),
    .din(dout_atmo_l0),
    .dout(dout_atmo_l)
);

// 氛围感增强EQ（4000Hz中心频点）- 右声道两级级联
audio_iir_step #(.K1(16'sd1773), .K2(16'sd855), .K3(16'sd1252)) u_iir_12(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[12]),
    .rst_n(run_rst_n),
    .din(sample_r),
    .dout(dout_atmo_r0)
);

audio_iir_step #(.K1(16'sd1479), .K2(16'sd756), .K3(16'sd1252)) u_iir_13(
    .clk(clk),
    .sample_en(sample_en),
    .out_valid(filter_done[13]),
    .rst_n(run_rst_n),
    .din(dout_atmo_r0),
    .dout(dout_atmo_r)
);


// 滤波器选择（优先级：sw1 > sw2 > sw3 > sw4 > sw5）
// sw1拨动：窄带通话滤波器（200-4000Hz电信标准）
// sw2拨动：低音增强EQ（300Hz中心频点）
// sw3拨动：人声增强EQ（2000Hz中心频点）
// sw4拨动：氛围感增强EQ（4000Hz中心频点）
// sw5拨动：窄带通话滤波器（与sw1效果一致，优先级最低）
// 均不拨：直通
assign agc_l = mode_q[1] ? dout_l2 : (mode_q[2] ? dout_ch_l : (mode_q[3] ? dout_voice_l : (mode_q[4] ? dout_atmo_l : (mode_q[5] ? dout_l2 : sample_l))));
assign agc_r = mode_q[1] ? dout_r2 : (mode_q[2] ? dout_ch_r : (mode_q[3] ? dout_voice_r : (mode_q[4] ? dout_atmo_r : (mode_q[5] ? dout_r2 : sample_r))));

// AGC模块
audio_agc_step agc_ins1(
   .clk(clk),
   .sample_en(sample_en),
   .out_valid(agc_done_r),
   .rst_n(run_rst_n),
   .din(agc_r),
   .exp_amp(ref_q),
   .dout(agc_out_r)
);

audio_agc_step agc_ins2(
   .clk(clk),
   .sample_en(sample_en),
   .out_valid(agc_done_l),
   .rst_n(run_rst_n),
   .din(agc_l),
   .exp_amp(ref_q),
   .dout(agc_out_l)
);

// sw0控制AGC开关
// sw0=1: 经过AGC
// sw0=0: 绕过AGC，直接输出滤波后的信号



assign tVAD = 1'b1;

endmodule