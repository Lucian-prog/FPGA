`timescale 1ps/1ps
module driver(
    input clka,
    input [7:0] data,
    input wire ack,
    input rst_n,
    output reg [7:0] data_tx,
    output reg req
);
//ack打拍
  reg ack_sync0, ack_sync1;
  always@(posedge clka or negedge rst_n)begin
    if(!rst_n)begin
      ack_sync0<=0;
      ack_sync1<=0;
    end
    else begin
      ack_sync0<=ack;
      ack_sync1<=ack_sync0;
    end
  end

//计时
  reg [4:0] cnt;
  always@(posedge clka or negedge rst_n)begin
    if(!rst_n)begin
      cnt<=0;
    end
    else if(req==1'b0 && ack_sync1==1'b0)begin
      cnt<=cnt+1;
    end
    else begin
      cnt<=0;
    end
  end

//req更新
  always@(posedge clka or negedge rst_n)begin
    if(!rst_n)begin
      req<=0;
    end
    else if(cnt==5'd16)begin
      req<=1;
    end
    else if(ack_sync1==1'b1)begin
      req<=0;
    end
  end
  
//data_tx更新
  always@(posedge clka or negedge rst_n)begin
    if(!rst_n)begin
      data_tx<=0;
    end
    else if(cnt==5'd16)begin
      data_tx<=data;
    end
  end

endmodule