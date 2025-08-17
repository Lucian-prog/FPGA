module led_twinkle(
   Clk,
   Reset_n,
   Led
    );
    
   input Clk;
   input Reset_n;
   output reg Led;
   
   reg[24:0]counter;
   
   always@(posedge Clk or negedge Reset_n)
   if(!Reset_n)
      counter<=0;
   else if(counter==25_000_000-1)
       counter<=0;
   else 
       counter<=counter+1'd1;    
       
   always@(posedge Clk or negedge Reset_n)
   if(!Reset_n)
      Led<=1'b0;
   else if(counter==25_000_000-1)
      Led<=!Led;
   
endmodule
