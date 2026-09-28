`timescale 1ps/1ps
module driver(
    input clka,
    input [7:0] data,
    input wire ack,
    input rst_n,
    output reg [7:0] data_tx,
    output reg req
);
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
  reg [4:0] cnt;
  always@(posedge clka or negedge rst_n)begin
    
  end

    




endmodule