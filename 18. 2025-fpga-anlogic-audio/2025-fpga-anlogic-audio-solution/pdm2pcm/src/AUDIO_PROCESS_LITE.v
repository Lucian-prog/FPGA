module AUDIO_PROCESS(
    input rst_n,
    input signed [15:0] audio_r,
    input signed [15:0] audio_l,
    input data_async,
    output signed [15:0] o_audio_r,
    output signed [15:0] o_audio_l
);
//1.双声道滤波器(时分复用*2)
//wire signed [23:0] af_fir_l;
//wire signed [23:0] af_fir_r;
/*FIR_APP fir_l_r_ins(
    .clk_60m(clk_60m),
    .rst_n(rst_n),
    .data_l(audio_l),
    .data_r(audio_r),
    .data_async(data_async),//48kHz脉冲,标识送数
    .data_valid(data_valid),

    .AF_data_l(af_fir_l),
    .AF_data_r(af_fir_r)
);
*/
wire signed [15:0] dout_l1,dout_r1;
wire signed [15:0] dout_l,dout_r;
iir u_iir_0(
    .clk(data_async),
    .rst_n(rst_n),
    .en(1'b1),
    .din(audio_l),
    .k1(1980),
    .k2(959),
    .k3(1026),
    .dout(dout_l1)
);
iir u_iir_1(
    .clk(data_async),
    .rst_n(rst_n),
    .en(1'b1),
    .din(dout_l1),
    .k1(1690),
    .k2(741),
    .k3(1026),
    .dout(o_audio_l)
);

iir u_iir_2(
    .clk(data_async),
    .rst_n(rst_n),
    .en(1'b1),
    .din(audio_r),
    .k1(1980),
    .k2(959),
    .k3(1026),
    .dout(dout_r1)
);
iir u_iir_3(
    .clk(data_async),
    .rst_n(rst_n),
    .en(1'b1),
    .din(dout_r1),
    .k1(1690),
    .k2(741),
    .k3(1026),
    .dout(o_audio_r)
);

// iir u_iir_1(
//     .clk(data_async),
//     .rst_n(rst_n),
//     .din(dout_r),
//     .k1(1992),
//     .k2(980),
//     .k3(161),
//     .dout()
// );



// iir u_iir_3(
//     .clk(data_async),
//     .rst_n(rst_n),
//     .din(dout_l),
//     .k1(1992),
//     .k2(980),
//     .k3(161),
//     .dout()
// );

endmodule