`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/08/19 17:30:18
// Design Name: 
// Module Name: digital_tube
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


module digital_tube(
    input wire clk,
    input wire rst_n,
    input wire [31:0]Disp_Data,
    output reg [7:0]SEL,
    output reg [7:0]SEG
    );
reg [29:0]div_cnt;      
parameter CLOCK_FREQ =50_000_000;
parameter TURN_FREQ= 1000;
parameter MCNT = CLOCK_FREQ / TURN_FREQ - 1;
          
always @(posedge clk or negedge rst_n)           
    begin                                        
    if(!rst_n)                               
        div_cnt <= 0;                                   
    else if(div_cnt == MCNT)                                
        div_cnt <= 0;                                 
    else                                     
        div_cnt <= div_cnt + 1;                               
    end
    
reg [3:0]data_temp;
reg [2:0]cnt_sel;
always @(posedge clk or negedge rst_n)           
    begin                                        
    if(!rst_n)                               
        cnt_sel <= 0;                                   
    else if(div_cnt == MCNT)                                
        cnt_sel <= cnt_sel + 1;                                 
    end

always@(posedge clk)
    begin
    case(cnt_sel)
        3'b000: SEL <= 8'b00000001; // Select first digit
        3'b001: SEL <= 8'b00000010; // Select second digit
        3'b010: SEL <= 8'b00000100; // Select third digit
        3'b011: SEL <= 8'b00001000; // Select fourth digit
        3'b100: SEL <= 8'b00010000; // Select fifth digit
        3'b101: SEL <= 8'b00100000; // Select sixth digit
        3'b110: SEL <= 8'b01000000; // Select seventh digit
        3'b111: SEL <= 8'b10000000; // Select eighth digit
    endcase
    end

always@(posedge clk)                                    
    begin
    case(data_temp)
        4'b0000: SEG <= 8'b11000000; // Display 0
        4'b0001: SEG <= 8'b11111001; // Display 1
        4'b0010: SEG <= 8'b10100100; // Display 2
        4'b0011: SEG <= 8'b10110000; // Display 3
        4'b0100: SEG <= 8'b10011001; // Display 4
        4'b0101: SEG <= 8'b10010010; // Display 5
        4'b0110: SEG <= 8'b10000010; // Display 6
        4'b0111: SEG <= 8'b11111000; // Display 7
        4'b1000: SEG <= 8'b10000000; // Display 8
        4'b1001: SEG <= 8'b10010000; // Display 9
        4'b1010: SEG <= 8'b10001000; // Display A
        4'b1011: SEG <= 8'b10000011; // Display B
        4'b1100: SEG <= 8'b11000110; // Display C
        4'b1101: SEG <= 8'b10100001; // Display D
        4'b1110: SEG <= 8'b10000110; // Display E
        4'b1111: SEG <= 8'b10001110; // Display F
    endcase
    end

always@(*)
   case(cnt_sel)
       3'b000: data_temp = Disp_Data[3:0];
       3'b001: data_temp = Disp_Data[7:4];
       3'b010: data_temp = Disp_Data[11:8];
       3'b011: data_temp = Disp_Data[15:12];
       3'b100: data_temp = Disp_Data[19:16];
       3'b101: data_temp = Disp_Data[23:20];
       3'b110: data_temp = Disp_Data[27:24];
       3'b111: data_temp = Disp_Data[31:28];
   endcase
endmodule
