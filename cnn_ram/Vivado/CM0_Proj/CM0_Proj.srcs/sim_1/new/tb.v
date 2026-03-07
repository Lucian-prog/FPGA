`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/06/07 19:43:14
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb();
reg clk;
reg rstn;
wire [7:0]gpio;

CortexM0_SoC CortexM0_SoC_inst(
        .clk(clk),
        .RSTn(rstn),
        .SWDIO(),  
        .SWCLK(),
        .GPIO(),
        .TXD(),
        .RXD()
);

initial begin
    clk = 0;
    rstn = 0;
    #1000
    rstn = 1;

end

always begin
    #20 clk = ~clk;
end

endmodule
