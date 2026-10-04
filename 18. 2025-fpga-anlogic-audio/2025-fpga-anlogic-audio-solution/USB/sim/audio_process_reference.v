// 修改前的算法连接，用于逐样本数值回归；仅供仿真。
// 系数显式写为 16 位，与原端口截断后的值一致。
module audio_process_reference(
    input rst_n,
    input signed [15:0] audio_r,
    input signed [15:0] audio_l,
    input data_async,
    input wire sw0,
    input wire sw1,
    input wire sw2,
    input wire sw3,
    input wire sw4,
    input wire sw5,
    input signed [15:0] audio_ref,
    output signed [15:0] o_audio_r,
    output signed [15:0] o_audio_l,
    output tVAD
);

wire signed [15:0] dout_l0,dout_r0,dout_l1,dout_r1,dout_l2,dout_r2;
wire signed [15:0] dout_ch_l,dout_ch_r;
wire signed [15:0] dout_voice_l, dout_voice_r;
wire signed [15:0] dout_atmo_l, dout_atmo_r;  // 氛围感增强输出
wire signed [15:0] dout_atmo_l0, dout_atmo_r0;  // 氛围感增强中间级
iir u_iir_0(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_l),
    .k1(16'sd1980),
    .k2(16'sd959),
    .k3(16'sd1026),
    .dout(dout_l1)
);
iir u_iir_1(
    .clk(data_async),
    .rst_n(rst_n),
    .din(dout_l1),
    .k1(16'sd1690),
    .k2(16'sd741),
    .k3(16'sd1026),
    .dout(dout_l2)
);

iir u_iir_2(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_r),
    .k1(16'sd1980),
    .k2(16'sd959),
    .k3(16'sd1026),
    .dout(dout_r1)
);
iir u_iir_3(
    .clk(data_async),
    .rst_n(rst_n),
    .din(dout_r1),
    .k1(16'sd1690),
    .k2(16'sd741),
    .k3(16'sd1026),
    .dout(dout_r2)
);
//中心频点300Hz
iir_ch u_iir_4(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_l),
    .k1(16'sd8020),
    .k2(16'sd3932),
    .k3(16'sd1322),
    .dout(dout_ch_l)
);
iir_ch u_iir_5(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_r),
    .k1(16'sd8020),
    .k2(16'sd3932),
    .k3(16'sd1322),
    .dout(dout_ch_r)
);

// 人声增强EQ（2000Hz中心频点）- 左声道两级级联
iir u_iir_6(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_l),
    .k1(16'sd1906),
    .k2(16'sd913),
    .k3(16'sd920),
    .dout(dout_l0)
);

iir u_iir_7(
    .clk(data_async),
    .rst_n(rst_n),
    .din(dout_l0),
    .k1(16'sd1720),
    .k2(16'sd814),
    .k3(16'sd920),
    .dout(dout_voice_l)
);

// 人声增强EQ（2000Hz中心频点）- 右声道两级级联
iir u_iir_8(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_r),
    .k1(16'sd1906),
    .k2(16'sd913),
    .k3(16'sd920),
    .dout(dout_r0)
);

iir u_iir_9(
    .clk(data_async),
    .rst_n(rst_n),
    .din(dout_r0),
    .k1(16'sd1720),
    .k2(16'sd814),
    .k3(16'sd920),
    .dout(dout_voice_r)
);

// 氛围感增强EQ（4000Hz中心频点）- 左声道两级级联
iir u_iir_10(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_l),
    .k1(16'sd1773),
    .k2(16'sd855),
    .k3(16'sd1252),
    .dout(dout_atmo_l0)
);

iir u_iir_11(
    .clk(data_async),
    .rst_n(rst_n),
    .din(dout_atmo_l0),
    .k1(16'sd1479),
    .k2(16'sd756),
    .k3(16'sd1252),
    .dout(dout_atmo_l)
);

// 氛围感增强EQ（4000Hz中心频点）- 右声道两级级联
iir u_iir_12(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_r),
    .k1(16'sd1773),
    .k2(16'sd855),
    .k3(16'sd1252),
    .dout(dout_atmo_r0)
);

iir u_iir_13(
    .clk(data_async),
    .rst_n(rst_n),
    .din(dout_atmo_r0),
    .k1(16'sd1479),
    .k2(16'sd756),
    .k3(16'sd1252),
    .dout(dout_atmo_r)
);

/*iir u_iir_2(
    .clk(data_async),
    .rst_n(rst_n),
    .din(audio_l),
    .k1(16'sd7932),
    .k2(16'sd3852),
    .k3(16'sd1963),
    .dout(dout_l)
);
*///中心频点500Hz

wire signed [15:0] agc_l,agc_r;
wire signed [15:0] agc_out_l, agc_out_r;

// 滤波器选择（优先级：sw1 > sw2 > sw3 > sw4 > sw5）
// sw1拨动：窄带通话滤波器（200-4000Hz电信标准）
// sw2拨动：低音增强EQ（300Hz中心频点）
// sw3拨动：人声增强EQ（2000Hz中心频点）
// sw4拨动：氛围感增强EQ（4000Hz中心频点）
// sw5拨动：窄带通话滤波器（与sw1效果一致，优先级最低）
// 均不拨：直通
assign agc_l = sw1 ? dout_l2 : (sw2 ? dout_ch_l : (sw3 ? dout_voice_l : (sw4 ? dout_atmo_l : (sw5 ? dout_l2 : audio_l))));
assign agc_r = sw1 ? dout_r2 : (sw2 ? dout_ch_r : (sw3 ? dout_voice_r : (sw4 ? dout_atmo_r : (sw5 ? dout_r2 : audio_r))));

// AGC模块
agc agc_ins1(
   .clk(data_async),
   .rst_n(rst_n),
   .din(agc_r),
   .exp_amp(audio_ref),
   .dout(agc_out_r)
);

agc agc_ins2(
   .clk(data_async),
   .rst_n(rst_n),
   .din(agc_l),
   .exp_amp(audio_ref),
   .dout(agc_out_l)
);

// sw0控制AGC开关
// sw0=1: 经过AGC
// sw0=0: 绕过AGC，直接输出滤波后的信号
assign o_audio_l = sw0 ? agc_out_l : agc_l;
assign o_audio_r = sw0 ? agc_out_r : agc_r;



assign tVAD = 1'b1;

endmodule
// 与原 Anlogic DSP 的 41x16 有符号组合乘法配置一致。
module DSP(output signed [56:0] p, input signed [40:0] a, input signed [15:0] b);
  assign p = a * b;
endmodule
