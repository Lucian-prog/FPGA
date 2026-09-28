`timescale 1ns / 1ps

module top_tb;

  // Parameters

  //Ports
  reg  clk50mhz;
  reg  rst_n;
  wire  mic_clk;
  wire  mic_ws;
  reg [3:0] mic_data;
  wire  usb_dp_pull;
  wire usb_dp;
  wire usb_dn;
  wire iic_0_scl;
  wire iic_0_sda;
  wire I2S_RCLK;
  wire I2S_BCLK;
  wire I2S_DO;
  wire I2S_MCLK;
  wire  led_usb;
  wire  led_sys;
  wire  led_error;
  wire  sk9822_clk;
  wire  sk9822_data;
  wire  uart_tx;

  top  top_inst (
    .clk50mhz(clk50mhz),
    .rst_n(rst_n),
    .mic_clk(mic_clk),
    .mic_ws(mic_ws),
    .mic_data(mic_data),
    .usb_dp_pull(usb_dp_pull),
    .usb_dp(usb_dp),
    .usb_dn(usb_dn),
    .iic_0_scl(iic_0_scl),
    .iic_0_sda(iic_0_sda),
    .I2S_RCLK(I2S_RCLK),
    .I2S_BCLK(I2S_BCLK),
    .I2S_DO(I2S_DO),
    .I2S_MCLK(I2S_MCLK),
    .led_usb(led_usb),
    .led_sys(led_sys),
    .led_error(led_error),
    .sk9822_clk(sk9822_clk),
    .sk9822_data(sk9822_data),
    .uart_tx(uart_tx)
  );

  //always #5  clk = ! clk ;
  initial
  begin
    clk50mhz=0;
    forever
      #10 clk50mhz = ~clk50mhz;
  end

  initial
  begin
    rst_n=0;
    #100;
    rst_n=1;
    $display("Simulation Start");
  end

  integer i;
  initial
    begin
      mic_data=4'b0000;

      #30000;
      $display("Start Mic Data Input");
      for(i=0;i<1000000000;i=i+1)
      begin
        @(posedge mic_clk);
        mic_data=$random;
      end
      $display("End Mic Data Input");
    end


  endmodule
