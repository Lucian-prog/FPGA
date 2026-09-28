`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// 模块: ES8388_init_table
// 说明: ES8388 初始化寄存器表（ROM），提供要写入的寄存器地址和值。
// 主要参数/端口:
//  - DATA_WIDTH / ADDR_WIDTH: ROM 数据与地址宽度
//  - addr/clk/q: ROM 读接口，根据 addr 返回 16bit 寄存器配置（高 8bit 为地址，低 8bit 为数据）
//  - dev_id: 目标设备 I2C 地址
//  - lut_size: 表长度（寄存器数量）
// 说明/备注:
//  - 表中包含 ES8388 上电初始化序列及延时项（例如写入 0x02_00 后需延时）。
// -----------------------------------------------------------------------------
module ES8388_init_table#(
    parameter DATA_WIDTH=16, 
    parameter ADDR_WIDTH=8
)(
	input [(ADDR_WIDTH-1):0] addr,
	input clk, 
	output reg [(DATA_WIDTH-1):0] q,
	output [7:0]dev_id,
	output [7:0]lut_size
);

	reg [DATA_WIDTH-1:0] rom[2**ADDR_WIDTH-1:0];
	
	assign dev_id = 8'h20;		// ES8388IIC�ӿ�������ַ
	assign lut_size = 8'd43;	//ES8388 �Ĵ�����ʼ������

    // MCLK 时钟为 8.192MHz
    // Line IN 初始化表
    always @ (*) begin
        /*
            说明：以某种模式（寄存器 0x08 的 bit[7] = 1）配置，FPGA 提供的 MCLK 为 8.192MHz。
            寄存器 0x0D 和 0x18 的低 5 位用于设置 MCLK/LRCK 比值。示例：设置为 0x04 时，LRCK = MCLK/512 = 16kHz。
            寄存器 0x08 的低 5 位用于设置 MCLK/SCLK 比值。
            同时需要确保 ADC 和 DAC 的位宽设置匹配，例如 16bit 时的 SCLK = 32 * LRCK。
            位宽对应关系：
              16bit: SCLK = 32 * LRCK
              18bit: SCLK = 36 * LRCK
              20bit: SCLK = 40 * LRCK
              24bit: SCLK = 48 * LRCK
              32bit: SCLK = 64 * LRCK
        */
		
//		rom[0 ] = 16'h01_58; 
//		rom[1 ] = 16'h01_50;  
//		rom[2 ] = 16'h02_F3;
//		rom[3 ] = 16'h02_F0;
//		rom[4 ] = 16'h2B_80; //ADC��DACʹ����ͬ��LRCK bit[7] Ϊ1
//		rom[5 ] = 16'h00_36;
//		rom[6 ] = 16'h08_84; //��ģʽ���ƼĴ�����bit[7]��1������ģʽ,����MCLK/SCLK�ı���bit��4��0������ SCLKΪ2.0148M
//		rom[7 ] = 16'h04_00;
//		rom[8 ] = 16'h0D_04; //����MCLK��Ƶ�ʵı���      ADCLRCK=MCLK/��Ӧ�������üĴ�������[4��0]��512 16K
//		rom[9 ] = 16'h18_04; 
//		rom[10] = 16'h05_00;
//		rom[11] = 16'h06_C3; 
//		rom[12] = 16'h0A_00; //Select Analog input channel for ADC (Lin1/Rin1)    LIN1:0X00		LIN2��0x52
//		rom[13] = 16'h0B_02; //(Select LIN1and RIN1 as differential input pairs)  LIN1:0X02    LIN2:0x82
//		rom[14] = 16'h0C_0C; //ADC Control: [1:0]=00(I2Sģʽ); [4:2]: 011: 16bit(0x0c); 000:24(0x00); 001:20(0x04); 010:18(0x08); 100:32(0x10)
//		rom[15] = 16'h17_18; //DAC Control: [2:1]=00(I2S);     [5:3]: 011: 16bit(0x18); 000:24(0x00); 001:20(0x08); 010:18(0x10); 100:32(0x20)
//		rom[16] = 16'h10_00; 
//		rom[17] = 16'h11_00; 
//		rom[18] = 16'h1A_00;
//		rom[19] = 16'h1B_00;
//		rom[20] = 16'h09_00;
//		rom[21] = 16'h12_E2;
//		rom[22] = 16'h13_C0;
//		rom[23] = 16'h14_12;
//		rom[24] = 16'h15_06;
//		rom[25] = 16'h16_C3;
//		rom[26] = 16'h27_B8;
//		rom[27] = 16'h2A_B8;
//		rom[28] = 16'h02_00;        //������Ҫ��ʱ500ms
//		rom[29] = 16'h2E_1E;
//		rom[30] = 16'h2F_1E;
//		rom[31] = 16'h30_1E;
//		rom[32] = 16'h31_1E;
//		rom[33] = 16'h04_36;    //0x30:ʹ��OUT1 [4]:ROUT1 enable; [5]:LOUT1 enable; 0x06:ʹ��OUT2 [2]:ROUT2 enable;[3]:LOUT2 enable
//		rom[34] = 16'h26_00;
//		rom[35] = 16'h03_09;
//		rom[36] = 16'h2E_1E;
//		rom[37] = 16'h2F_1E;
//		rom[38] = 16'h30_1E;
//		rom[39] = 16'h31_1E;
//		rom[40] = 16'h32_00;
//		rom[41] = 16'h33_aa;
//		rom[42] = 16'h34_aa;

    rom[0 ] = 16'h00_80;       /* 复位 ES8388 */
    rom[1 ] = 16'h00_16;
    rom[2 ] = 16'h01_58;
    rom[3 ] = 16'h01_50;
    rom[4 ] = 16'h02_F3;
    rom[5 ] = 16'h02_F0;
    rom[6 ] = 16'h2B_80; // ADC 与 DAC 使用相同 LRCK，寄存器 bit[7] 为 1
    rom[7 ] = 16'h00_36;
    rom[8 ] = 16'h08_00; // 配置模式寄存器（示例）：当 bit[7]=1 表示某种工作模式，低五位设置 MCLK/SCLK 比值（示例 SCLK=2.0148MHz）
    rom[9 ] = 16'h03_09;//<-
    rom[10] = 16'h04_00;
    rom[11] = 16'h0D_02; // 设置 MCLK 与 LRCK 比值，例如 ADCLRCK = MCLK / 对应分频值（低5位），示例：512 -> 16KHz
    rom[12] = 16'h18_02;
    rom[13] = 16'h05_00;
    rom[14] = 16'h06_C3;
    rom[15] = 16'h0A_00; // 选择 ADC 模拟输入通道（例如 LIN1/RIN1）
    rom[16] = 16'h0B_02; //(Select LIN1and RIN1 as differential input pairs)  LIN1:0X02    LIN2:0x82
    rom[17] = 16'h0C_0c; //ADC Control: [1:0]=00(I2Sģʽ); [4:2]: 011: 16bit(0x0c); 000:24(0x00); 001:20(0x04); 010:18(0x08); 100:32(0x10)
    rom[18] = 16'h17_18; //DAC Control: [2:1]=00(I2S);     [5:3]: 011: 16bit(0x18); 000:24(0x00); 001:20(0x08); 010:18(0x10); 100:32(0x20)
    rom[19] = 16'h10_00;
    rom[20] = 16'h11_00;
    rom[21] = 16'h1A_00;
    rom[22] = 16'h1B_00;
    rom[23] = 16'h09_88;// 配置 L/R PGA 增益为 +24dB，ADC 数据位宽设置为 16bit（left data = left adc）
    rom[24] = 16'h12_11;//�ر� ALC
    rom[25] = 16'h13_C0;
    rom[26] = 16'h14_32;
    rom[27] = 16'h15_06;
    rom[28] = 16'h16_C3;
    rom[29] = 16'h27_B8;
    rom[30] = 16'h2A_B8;
    rom[31] = 16'h02_00;        // 写入后需要延时 500ms
    rom[32] = 16'h2E_1E;
    rom[33] = 16'h2F_1E;
    rom[34] = 16'h30_1E;
    rom[35] = 16'h31_1E;
    rom[36] = 16'h04_36;    // 寄存器 0x30: 启用 OUT1/OUT2（例如 ROUT1/LOUT1，ROUT2/LOUT2）
    rom[37] = 16'h26_00;
    rom[38] = 16'h03_09;
    rom[39] = 16'h2E_1E;
    rom[40] = 16'h2F_1E;
    rom[41] = 16'h30_1E;
    rom[42] = 16'h31_1E;

	end
	always @ (posedge clk)
	begin
		q <= rom[addr];
	end
endmodule
