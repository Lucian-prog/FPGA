//N是分频系数,WIDTH要大于等于能够表示N的位数
module clkdiv
    #(
    parameter			WIDTH	=	3,
	parameter			N		=	5
    )(
	//INPUT
	input      clk,
	input      rst_n,
	//OUTPUT
	output     clkout			
);

	//********************
	//REGS
	reg 	[WIDTH-1:0]		cnt_p,cnt_n;
	reg						clk_p,clk_n;
 
	assign clkout = (N==1)?clk:(N[0])?(clk_p&clk_n):clk_n;
    //根据奇偶性选择对应的通道
    //奇数由于不等长，所以通过错位合并的形式
    
	//Sequential logic style
	always @ (posedge clk) //上升沿计数器，范围0-(N-1)
		begin
			if(!rst_n)
				cnt_p<=0;
			else if (cnt_p==(N-1))
				cnt_p<=0;
			else cnt_p<=cnt_p+1'b1;
		end
 
	always @ (negedge clk) //下降沿计数器，范围0-(N-1)
		begin
			if(!rst_n)
				cnt_n<=0;
			else if (cnt_n==(N-1))
				cnt_n<=0;
			else cnt_n<=cnt_n+1'b1;
		end
 
	always @ (posedge clk) //若N为偶数，在上升沿翻转电平
		begin
			if(!rst_n)
				clk_p<=0;
			else if (cnt_p<(N>>1))  
				clk_p<=0;
			else 
				clk_p<=1;
		end
 
	always @ (negedge clk) //若N为奇数，在下降沿翻转电平
		begin
			if(!rst_n)
				clk_n<=0;
			else if (cnt_n<(N>>1))  
				clk_n<=0;
			else 
				clk_n<=1;
		end
endmodule
