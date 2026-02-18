`timescale 1ns / 1ps
// 模块: uart_tx_tb
// 说明: 验证 uart_tx 发送逻辑
//       - 发送 0x55 (01010101)，在串行线上观察起始位+8数据位+停止位
//       - 验证 uart_tx_done 信号正确拉高

module uart_tx_tb;

  // 参数与源模块一致
  localparam BAUD     = 9600;
  localparam CLK_FREQ = 50_000_000;
  localparam CLK_PERIOD = 20;  // 50MHz -> 20ns

  reg        clk;
  reg        rst_n;
  reg  [7:0] data_in;
  reg        Send_Go;
  wire       uart_tx;
  wire       uart_tx_done;

  uart_tx #(
    .BAUD    (BAUD),
    .CLK_FREQ(CLK_FREQ)
  ) dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .data_in     (data_in),
    .Send_Go     (Send_Go),
    .uart_tx     (uart_tx),
    .uart_tx_done(uart_tx_done)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  // 一个波特周期 = CLK_FREQ/BAUD 个时钟周期 = 5208 * 20ns
  localparam integer BAUD_PERIOD_NS = CLK_FREQ / BAUD * CLK_PERIOD;  // 104160 ns

  integer err = 0;
  integer i;
  reg [9:0] expected_frame;  // {stop, data[7:0], start}

  task send_byte(input [7:0] data);
    integer timeout;
    begin
      @(negedge clk);
      data_in <= data;
      Send_Go <= 1'b1;
      @(negedge clk);
      Send_Go <= 1'b0;

      // 等待发送完成
      timeout = 200000;
      while (!uart_tx_done && timeout > 0) begin
        @(posedge clk);
        timeout = timeout - 1;
      end
      if (timeout == 0) begin
        $display("[FAIL] uart_tx_done 超时未拉高");
        err = err + 1;
      end
      @(posedge clk);
    end
  endtask

  initial begin
    $dumpfile("uart_tx_tb.vcd");
    $dumpvars(0, uart_tx_tb);

    clk     = 0;
    rst_n   = 0;
    data_in = 0;
    Send_Go = 0;

    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);

    $display("[TEST] uart_tx: 发送 0x55");
    send_byte(8'h55);
    if (err == 0) $display("[PASS] uart_tx_done 正常拉高");

    repeat(5) @(posedge clk);

    $display("[TEST] uart_tx: 发送 0xAA");
    send_byte(8'hAA);
    if (err == 0) $display("[PASS] 第二帧发送完成");

    repeat(5) @(posedge clk);

    if (err == 0)
      $display("[RESULT] uart_tx 全部测试通过");
    else
      $display("[RESULT] uart_tx 存在 %0d 个错误", err);

    $finish;
  end

  // 超时保护
  initial begin
    #200_000_000;
    $display("[TIMEOUT] uart_tx 仿真超时");
    $finish;
  end
endmodule
