`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// 模块: ES8388_Init
// 说明: 负责给 ES8388 音频编解码器下发初始化寄存器配置（通过 I2C），并在完成后产生 Init_Done 信号。
// 主要端口:
//  - Clk / Rst_n: 时钟与复位
//  - I2C_Init_Done: 初始化完成指示
//  - i2c_sdat / i2c_sclk: I2C 总线接口
// 说明/备注:
//  - 在上电/复位后延时一段时间，开始向 ES8388 写入初始化表（由 ES8388_init_table 提供）。
// -----------------------------------------------------------------------------
module ES8388_Init(
	Clk,
	Rst_n,

	I2C_Init_Done,
	i2c_sdat,
	i2c_sclk
);

	input Clk;
	input Rst_n;
	
	inout i2c_sdat;
	output i2c_sclk;
	output I2C_Init_Done;

	// 延时计数与初始化使能信号（用于在复位后等待一段时间再启动 I2C 初始化）
	reg [31:0]Delay_Cnt;
	reg Init_en;
	always@(posedge Clk or negedge Rst_n)
	begin
		if(!Rst_n)
			Delay_Cnt <= 'd0;
		else if(Delay_Cnt <  'd12000)
			Delay_Cnt <= Delay_Cnt + 8'd1;
		else
			Delay_Cnt <= Delay_Cnt;
	end	
	
	always@(posedge Clk or negedge Rst_n)
	begin
		if(!Rst_n)
			Init_en <= 1'b0;
		else if(Delay_Cnt == 'd11999)
			Init_en <= 1'b1;
		else
			Init_en <= 1'b0;
	end

	I2C_Init_Dev I2C_Init_Dev(
		.Clk(Clk),
		.Rst_n(Rst_n),
		.Go(Init_en),
		.Init_Done(I2C_Init_Done),
		.i2c_sclk(i2c_sclk),
		.i2c_sdat(i2c_sdat)
	);
endmodule
