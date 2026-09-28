`timescale 1ps/1ps
//============================================================================
// dds_sine.v : 简化版 DDS 正弦信号发生器（FIFO 仿真激励源）
//----------------------------------------------------------------------------
// DDS 最小五脏：FCW -> 相位累加器 -> 正弦 ROM -> 幅度输出
//
// 频率公式： f_out = i_freq_word * f_clk / 2^PHASE_W
//   例：f_clk=100MHz, FCW=2^26 -> f_clk/64，64 拍一个正弦周期
//
// i_en=0 时相位冻结（接 ~FIFO满 做反压），恢复后从冻结点无缝续上
//============================================================================
module dds_sine #(
    parameter PHASE_W = 32,             // 相位累加器位宽（决定频率分辨率）
    parameter LUT_AW  = 8,              // ROM 地址位宽（2^8 = 256 点/周期）
    parameter OUT_W   = 32              // 输出幅度位宽（有符号）
)(
    input  wire                     i_sys_clk,
    input  wire                     i_sys_rst_n,
    input  wire                     i_en,        // 0=冻结相位，1=推进并产出样本
    input  wire [PHASE_W-1:0]       i_freq_word, // 频率控制字 FCW，可运行时切换
    output wire signed [OUT_W-1:0]  o_sine       // 正弦样本，i_en=1 的拍有效
);

    // 相位累加器：每个使能拍 +FCW，2^PHASE_W 溢出一次即一个正弦周期
    reg [PHASE_W-1:0] r_phase;
    always @(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if (!i_sys_rst_n)
            r_phase <= {PHASE_W{1'b0}};
        else if (i_en)
            r_phase <= r_phase + i_freq_word;
    end

    // 正弦 ROM：0 时刻 $sin 填表（仿真用；Vivado 综合同样支持 initial ROM）
    // 幅度上限取 2^(OUT_W-1)-1，防止 sin=+1 时补码溢出
    localparam LUT_DEPTH = 1 << LUT_AW;    // ROM 深度：2^LUT_AW 个点/周期
    reg signed [OUT_W-1:0] rom_sine [0:LUT_DEPTH-1];
    integer k;
    initial begin
        for (k = 0; k < LUT_DEPTH; k = k + 1)
            // 除法用 2.0 开头保证 real 运算（integer/integer 会整除成 0！）
            rom_sine[k] = $rtoi((2.0**(OUT_W-1) - 1.0) * $sin(2.0*3.14159265*k/LUT_DEPTH));
    end

    // 取相位高 LUT_AW 位（[31:24]）查表，组合直出：i_en=1 的拍 o_sine 即有效样本，同拍相位才 +FCW
    assign o_sine = rom_sine[r_phase[PHASE_W-1:PHASE_W-LUT_AW]];

endmodule
