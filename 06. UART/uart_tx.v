`timescale 1ns / 1ps
module uart_tx (
    input wire clk,
    input wire rst_n,
    input wire [7:0] data_in,
    input wire Send_Go,
    output reg uart_tx,
    output reg uart_tx_done
);
  parameter BAUD=9600;
  parameter CLK_FREQ=50_000_000;
  parameter BAND_DIV_CNT_MAX = CLK_FREQ / BAUD - 1;
  wire w_uart_tx_done;
  reg band_cnt_en;
  reg [29:0] band_div_cnt;
  reg [3:0] bit_cnt;
  //parameter BAND_DIV_CNT_MAX = 13'd5207;
  parameter BAND_CNT_MAX = 4'd9;
  //parameter BAND_DLY_CNT_MAX = 26'd50_000_00-1;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      band_div_cnt <= 0;
    end else if (band_cnt_en) begin
      if (band_div_cnt == BAND_DIV_CNT_MAX) begin
        band_div_cnt <= 0;
      end else begin
        band_div_cnt <= band_div_cnt + 1;
      end
    end else begin
      band_div_cnt <= 0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bit_cnt <= 0;
    end else if (band_div_cnt == BAND_DIV_CNT_MAX) begin
      if (bit_cnt == BAND_CNT_MAX) bit_cnt <= 0;
      else bit_cnt <= bit_cnt + 1;
    end
  end

  //reg [25:0] delay_cnt;  //延时计数器
  //always @(posedge clk or negedge rst_n) begin
  //  if (!rst_n) begin
  //    delay_cnt <= 0;
  //  end else if (delay_cnt == BAND_DLY_CNT_MAX) begin
  //    delay_cnt <= 0;
  //  end else begin
  //    delay_cnt <= delay_cnt + 1;
  //  end
  //end
  reg [7:0] r_Data;  //接收数据寄存器
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_Data <= 0;
    end else if (Send_Go) begin
      r_Data <= data_in;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      uart_tx <= 1;
    end else if (band_cnt_en == 0) begin
      uart_tx <= 1;
    end else begin
      case (bit_cnt)
        4'd0: uart_tx <= 0;
        4'd1: uart_tx <= r_Data[0];
        4'd2: uart_tx <= r_Data[1];
        4'd3: uart_tx <= r_Data[2];
        4'd4: uart_tx <= r_Data[3];
        4'd5: uart_tx <= r_Data[4];
        4'd6: uart_tx <= r_Data[5];
        4'd7: uart_tx <= r_Data[6];
        4'd8: uart_tx <= r_Data[7];
        BAND_CNT_MAX: uart_tx <= 1;
        default: uart_tx <= 1;
      endcase
    end
  end

  //led翻转逻辑
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      band_cnt_en <= 0;
    end else if (Send_Go) begin
      band_cnt_en <= 1;
    end else if(bit_cnt == BAND_CNT_MAX && band_div_cnt == BAND_DIV_CNT_MAX) begin
      band_cnt_en <= 0;
    end
  end

  assign w_uart_tx_done = (bit_cnt == BAND_CNT_MAX && band_div_cnt == BAND_DIV_CNT_MAX);

  always @(posedge clk or negedge rst_n)begin
    if (!rst_n) begin
      uart_tx_done <= 0;
    end else begin
      uart_tx_done <= w_uart_tx_done;
    end
  end

endmodule
