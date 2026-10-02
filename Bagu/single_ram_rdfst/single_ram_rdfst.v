`timescale 1ns / 1ps 
module single_ram_rdfst(
  input wire clk,
  input wire rst_n,
  input wire [3:0] addr_wr,
  input wire [3:0] addr_rd,
  input wire [7:0] data_in,
  input wire we,
  input wire re,
  output reg [7:0] data_out
);                         
  reg [7:0] ram [0:15]; // 16 x 8-bit RAM
  integer i;
  always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
      for(i=0;i<16;i++)
      ram[i] <= 8'h0;
    end
    else if (we) begin
      ram[addr_wr]<=data_in;
    end
  end       

  always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
      data_out<=8'h0;
    end
    else if(re)begin
      data_out<=ram[addr_rd];
    end
  end

                                                                 
endmodule                                                          
