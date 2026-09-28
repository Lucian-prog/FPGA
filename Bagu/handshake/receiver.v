`timescale 1ps/1ps
module receiver(
  input wire clkb,
  input wire [7:0] data_tx,
  input wire rst_n,
  input wire req,
  output reg ack,
  output wire [7:0] data_o
);
  reg req_sync0, req_sync1;
  always@(posedge clkb or negedge rst_n)begin
    if(!rst_n) begin
      req_sync0<=0;
      req_sync1<=0;
    end
    else begin
      req_sync0<=req;
      req_sync1<=req_sync0;
    end
  end  
  
  reg data_r;
  always@(posedge clkb or negedge rst_n)begin
    if(!rst_n)begin
      data_r<=0;
      ack<=0;
    end
    else if(req_sync1&&(!ack))begin
      data_r<=data_tx;
      ack<=1;
    end
    else begin
      data_r<=data_r;
    end
  end


  assign data_o=data_r;
  
  

endmodule //receiver
