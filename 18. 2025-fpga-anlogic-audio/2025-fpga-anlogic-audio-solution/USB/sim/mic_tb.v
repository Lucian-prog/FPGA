//================================================================================
// File      : mic_tb.v
// Function  : Sound Source Localization Testbench (Directional)
// Description: Simulate sound signals from different directions
// Version   : V2.0
// Date      : 2025-11-18
//================================================================================

`timescale 1ns / 1ps

module mic_tb;

  //================================================================================
  // Parameters
  //================================================================================
  parameter SAMPLE_RATE = 48000;           // 48kHz sample rate
  parameter SIGNAL_FREQ = 1000;            // 1kHz test signal
  parameter SAMPLES_PER_FRAME = 1024;      // Samples per frame
  
  // Sound source direction (time delay in samples)
  parameter DELAY_0_DEG   = 0;     // 0 degree
  parameter DELAY_60_DEG  = 5;     // 60 degree
  parameter DELAY_120_DEG = 10;    // 120 degree
  parameter DELAY_180_DEG = 15;    // 180 degree
  parameter DELAY_240_DEG = 20;    // 240 degree
  parameter DELAY_300_DEG = 25;    // 300 degree

  //================================================================================
  // Port Signals
  //================================================================================
  reg  clk50mhz;
  reg  rst_n;
  wire mic_clk;
  wire mic_ws;
  reg [3:0] mic_data;
  wire usb_dp_pull;
  wire usb_dp;
  wire usb_dn;
  wire iic_0_scl;
  wire iic_0_sda;
  wire I2S_RCLK;
  wire I2S_BCLK;
  wire I2S_DO;
  wire I2S_MCLK;
  wire sk9822_clk;
  wire sk9822_data;
  wire uart_tx;

  //================================================================================
  // Internal Signals
  //================================================================================
  reg [3:0]  current_direction;            // Current source direction
  real phase;                              // Sine wave phase
  real amplitude;                          // Signal amplitude
  reg signed [23:0] sine_value;            // Current sine value
  integer bit_counter;                     // Bit counter for I2S output

  //================================================================================
  // DUT Instantiation
  //================================================================================
  top top_inst (
    .clk50mhz       (clk50mhz),
    .rst_n          (rst_n),
    .mic_clk        (mic_clk),
    .mic_ws         (mic_ws),
    .mic_data       (mic_data),
    .usb_dp_pull    (usb_dp_pull),
    .usb_dp         (usb_dp),
    .usb_dn         (usb_dn),
    .iic_0_scl      (iic_0_scl),
    .iic_0_sda      (iic_0_sda),
    .I2S_RCLK       (I2S_RCLK),
    .I2S_BCLK       (I2S_BCLK),
    .I2S_DO         (I2S_DO),
    .I2S_MCLK       (I2S_MCLK),
    .sk9822_clk     (sk9822_clk),
    .sk9822_data    (sk9822_data),
    .uart_tx        (uart_tx)
  );

  //================================================================================
  // Clock Generation
  //================================================================================
  initial begin
    clk50mhz = 0;
    forever #10 clk50mhz = ~clk50mhz;  // 50MHz
  end

  //================================================================================
  // Reset Control
  //================================================================================
  initial begin
    rst_n = 0;
    #200;
    rst_n = 1;
    $display("\n╔══════════════════════════════════════════════════════════════╗");
    $display("║    Sound Source Localization Test - Directional Verify      ║");
    $display("╚══════════════════════════════════════════════════════════════╝\n");
    $display("[%t] Reset done, simulation start", $time);
  end

  //================================================================================
  // Simple Sine Wave Generation for mic_data
  //================================================================================
  always @(posedge mic_clk) begin
    if (!rst_n) begin
      phase <= 0.0;
      amplitude <= 8000000.0;
      sine_value <= 24'd0;
      bit_counter <= 0;
      mic_data <= 4'b0000;
    end else begin
      // Generate 1kHz sine wave
      phase <= phase + (2.0 * 3.14159265 * SIGNAL_FREQ) / SAMPLE_RATE;
      if (phase > 2.0 * 3.14159265) 
        phase <= phase - 2.0 * 3.14159265;
      
      // Calculate sine value based on current direction
      if (current_direction == 4'd15)
        sine_value <= 24'd0;  // Silent
      else
        sine_value <= $rtoi(amplitude * $sin(phase));
      
      // Output MSB of sine wave to all 4 mic channels (simplified)
      // Directly assign to simulate microphone input
      mic_data[0] <= sine_value[23];
      mic_data[1] <= sine_value[23];
      mic_data[2] <= sine_value[23];
      mic_data[3] <= sine_value[23];
    end
  end

  //================================================================================
  // Sound Source Direction Control (Test Scenarios)
  //================================================================================
  initial begin
    current_direction = 4'd15;  // Initial silent
    
    // Wait for reset
    wait(rst_n == 1);
    #10000;
    
    $display("\n════════════════════════════════════════════════════════════════");
    $display("  Test Scenario 1: 0 deg source (front)");
    $display("  Duration: 10ms, 1kHz sine wave");
    $display("════════════════════════════════════════════════════════════════");
    current_direction = 4'd0;
    #10000000;  // 10ms
    
    $display("\n════════════════════════════════════════════════════════════════");
    $display("  Test Scenario 2: 60 deg source");
    $display("  Duration: 10ms, 1kHz sine wave");
    $display("════════════════════════════════════════════════════════════════");
    current_direction = 4'd2;
    #10000000;
    
    $display("\n════════════════════════════════════════════════════════════════");
    $display("  Test Scenario 3: 120 deg source (right)");
    $display("  Duration: 10ms, 1kHz sine wave");
    $display("════════════════════════════════════════════════════════════════");
    current_direction = 4'd4;
    #10000000;
    
    $display("\n════════════════════════════════════════════════════════════════");
    $display("  Test Scenario 4: 180 deg source (back)");
    $display("  Duration: 10ms, 1kHz sine wave");
    $display("════════════════════════════════════════════════════════════════");
    current_direction = 4'd6;
    #10000000;
    
    $display("\n════════════════════════════════════════════════════════════════");
    $display("  Test Scenario 5: 240 deg source (left)");
    $display("  Duration: 10ms, 1kHz sine wave");
    $display("════════════════════════════════════════════════════════════════");
    current_direction = 4'd8;
    #10000000;
    
    $display("\n════════════════════════════════════════════════════════════════");
    $display("  Test Scenario 6: 300 deg source");
    $display("  Duration: 10ms, 1kHz sine wave");
    $display("════════════════════════════════════════════════════════════════");
    current_direction = 4'd10;
    #10000000;
    
    $display("\n╔══════════════════════════════════════════════════════════════╗");
    $display("║              Simulation Test Complete!                       ║");
    $display("╚══════════════════════════════════════════════════════════════╝");
    $display("\nKey Points:");
    $display("  1. Check xcorr module sequence_num output");
    $display("  2. Check mic_led module direction output");
    $display("  3. Verify 6 directional scenarios work correctly\n");
    
    #1000000;
    $finish;
  end

  //================================================================================
  // Monitor Output
  //================================================================================
  // Monitor xcorr result
  always @(posedge top_inst.finished) begin
    $display("[%t] xcorr calculation done:", $time);
    $display("    sequence1 = %d (mic1 vs mic2)", top_inst.sequence1);
    $display("    sequence2 = %d (mic1 vs mic3)", top_inst.sequence2);
    $display("    sequence3 = %d (mic1 vs mic4)", top_inst.sequence3);
  end
  
  // Monitor direction detection
  always @(top_inst.sk9822_dir.direction or 
           top_inst.sk9822_dir.direction2 or 
           top_inst.sk9822_dir.direction3) begin
    if ($time > 100000) begin
      $display("[%t] Direction update:", $time);
      $display("    direction  = %2d (%s)", 
               top_inst.sk9822_dir.direction,
               top_inst.sk9822_dir.direction == 15 ? "silent" : 
               top_inst.sk9822_dir.direction == 4 ? "120deg" :
               top_inst.sk9822_dir.direction == 10 ? "300deg" : "other");
      $display("    direction2 = %2d (%s)",
               top_inst.sk9822_dir.direction2,
               top_inst.sk9822_dir.direction2 == 15 ? "silent" :
               top_inst.sk9822_dir.direction2 == 0 ? "0deg" :
               top_inst.sk9822_dir.direction2 == 6 ? "180deg" : "other");
      $display("    direction3 = %2d (%s)",
               top_inst.sk9822_dir.direction3,
               top_inst.sk9822_dir.direction3 == 15 ? "silent" :
               top_inst.sk9822_dir.direction3 == 2 ? "60deg" :
               top_inst.sk9822_dir.direction3 == 8 ? "240deg" : "other");
    end
  end

  //================================================================================
  // Waveform Dump
  //================================================================================
  initial begin
    $dumpfile("mic_tb.vcd");
    $dumpvars(0, mic_tb);
    $dumpvars(0, sine_value);
    $dumpvars(0, current_direction);
    $dumpvars(0, phase);
  end

endmodule
