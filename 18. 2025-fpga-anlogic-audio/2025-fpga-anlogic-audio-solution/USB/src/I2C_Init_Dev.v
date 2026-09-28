/*============================================================================
*
*  LOGIC CORE:          ʹ��IIC��ʼ��һ���豸�ļĴ��������ļ�	
*  MODULE NAME:         I2C_Init_Dev()
*  COMPANY:             �人о·��Ƽ����޹�˾
*                       http://xiaomeige.taobao.com
*	author:					С÷��
*	Website:					www.corecourse.cn
*  REVISION HISTORY:  
*
*    Revision 1.0  04/10/2019     Description: Initial Release.
*
*  FUNCTIONAL DESCRIPTION:
===========================================================================*/

module I2C_Init_Dev(
	Clk,
	Rst_n,
	
	Go,
	Init_Done,
	
	i2c_sclk,
	i2c_sdat
);

	input Clk;
	input Rst_n;
	input Go;
	output reg Init_Done;
	
	output i2c_sclk;
	inout i2c_sdat;
	
	wire [15:0]addr;
	reg wrreg_req;
	reg rdreg_req;
	wire [7:0]wrdata;
	
	wire [7:0]rddata;
	wire RW_Done;
	wire ack;
	reg [31:0] i2c_dly_cnt_max;
	
	wire [7:0]lut_size;	//��ʼ��������Ҫ�������������
	
	reg [7:0]cnt;	//�������������
	
	always@(posedge Clk or negedge Rst_n)
	if(!Rst_n)
		cnt <= 0;
	else if(Go) 
		cnt <= 0;
	else if(cnt < lut_size)begin
		if(RW_Done && (!ack))
			cnt <= cnt + 1'b1;
		else
			cnt <= cnt;
	end
	else
		cnt <= cnt;  // ← 改为保持，而不是清零
		
	always@(posedge Clk or negedge Rst_n)
	if(!Rst_n)
		Init_Done <= 1'b0;
	else if(Go) 
		Init_Done <= 1'b0;
	else if(cnt == lut_size)
		Init_Done <= 1'b1;
	else
		Init_Done <= Init_Done;  // ← 添加保持逻辑

	reg [1:0]state;
		
	always@(posedge Clk or negedge Rst_n)
	if(!Rst_n)begin
		state <= 0;
		wrreg_req <= 1'b0;
		i2c_dly_cnt_max <= 32'd0;
	end
	else if(cnt < lut_size)begin
		case(state)
			0:
				if(Go)
					state <= 1;
				else
					state <= 0;
			
			1:
				begin
					wrreg_req <= 1'b1;
					state <= 2;
					if(cnt == 28)
						i2c_dly_cnt_max <= 32'd24999999; //��ʱ500ms
					else
						i2c_dly_cnt_max <= 32'h0;
				end
				
			2:
				begin
					wrreg_req <= 1'b0;
					if(RW_Done)
						state <= 1;
					else
						state <= 2;
				end
				
			default:state <= 0;
		endcase
	end
	else
		state <= 0;

	wire [15:0]lut;
	wire [7:0]dev_id;
	
	ES8388_init_table ES8388_init_table(
		.dev_id(dev_id),
		.lut_size(lut_size),
		
		.addr(cnt),
		.clk(Clk),
		.q(lut)
	);
	
	assign addr = lut[15:8];
	assign wrdata = lut[7:0];

  i2c_control i2c_control(
    .Clk         (Clk             ),
    .Rst_n       (Rst_n           ),
    .wrreg_req   (wrreg_req       ),
    .rdreg_req   (0               ),
    .addr        (addr            ),
    .addr_mode   (0       ),
    .wrdata      (wrdata          ),
    .rddata      (rddata          ),
    .device_id   (dev_id       ),
    .RW_Done     (RW_Done         ),
    .ack         (ack             ),
    .dly_cnt_max (i2c_dly_cnt_max ),
    .i2c_sclk    (i2c_sclk        ),
    .i2c_sdat    (i2c_sdat        )
  );

endmodule
