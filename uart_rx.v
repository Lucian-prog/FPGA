`timescale 1ns / 1ps

module uart_rx (
    input clk,
    input rst_n,
    input uart_rx,
    output reg rx_done,
    output reg [7:0] rx_data
);

  parameter CLK_FREQ = 50000000;
  parameter BAUD = 9600;
  parameter MCNT_BAUD = CLK_FREQ / BAUD - 1;
  reg [7:0] r_rx_data;
  wire w_rx_done;
  reg [29:0] baud_div_cnt;
  reg en_baud_cnt;
  reg [3:0] bit_cnt;
  wire nedge_uart_rx;
  reg r_uart_rx;
  reg diff0_uart_rx, diff1_uart_rx;
  //波特率计数器逻辑
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_div_cnt <= 0;
    end else if (en_baud_cnt) begin
      if (baud_div_cnt == MCNT_BAUD) begin
        baud_div_cnt <= 0;
      end else begin
        baud_div_cnt <= baud_div_cnt + 1;
      end
    end else begin
      baud_div_cnt <= 0;
    end
  end

  //UART信号边沿检测逻辑(包含二次亚稳态消除)
  always @(posedge clk) begin
    diff0_uart_rx <= uart_rx;
  end

  always @(posedge clk) begin
    diff1_uart_rx <= diff0_uart_rx;
  end
  always @(posedge clk) begin
    r_uart_rx <= uart_rx;
  end
  assign nedge_uart_rx = (diff1_uart_rx) && (!r_uart_rx);

  //波特率计数器使能模块
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      en_baud_cnt <= 0;
    end else if (nedge_uart_rx) begin
      en_baud_cnt <= 1;
    end else if ((baud_div_cnt == MCNT_BAUD / 2) && (bit_cnt == 0) && (diff1_uart_rx == 1)) begin
      en_baud_cnt <= 0;
    end else if ((baud_div_cnt == MCNT_BAUD/2) && (bit_cnt == 9)) begin
      en_baud_cnt <= 0;
    end
  end

  //位计数器逻辑模块
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bit_cnt <= 0;
    end
    else if((baud_div_cnt == MCNT_BAUD/2)&&(bit_cnt==9)) begin
      bit_cnt <=0;
    end
    else if(baud_div_cnt == MCNT_BAUD) begin
      bit_cnt <= bit_cnt + 1;
    end
  end

  //位接收逻辑模块
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_rx_data <= 0;
    end else if (baud_div_cnt == MCNT_BAUD / 2) begin
      case (bit_cnt)
        1: r_rx_data[0] <= diff1_uart_rx;
        2: r_rx_data[1] <= diff1_uart_rx;
        3: r_rx_data[2] <= diff1_uart_rx;
        4: r_rx_data[3] <= diff1_uart_rx;
        5: r_rx_data[4] <= diff1_uart_rx;
        6: r_rx_data[5] <= diff1_uart_rx;
        7: r_rx_data[6] <= diff1_uart_rx;
        8: r_rx_data[7] <= diff1_uart_rx;
        default: r_rx_data <= r_rx_data;
      endcase
    end
  end

  //接收完成标志信号
  assign w_rx_done = (baud_div_cnt == MCNT_BAUD/2) && (bit_cnt == 9);
  always @(posedge clk) begin
    rx_done <= w_rx_done;
  end

  always@(posedge clk) begin
    if(w_rx_done) begin
      rx_data <=r_rx_data;
    end
  end

endmodule
