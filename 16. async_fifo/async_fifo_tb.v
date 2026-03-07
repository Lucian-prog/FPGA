`timescale 1ns / 1ps
// 模块: async_fifo_tb
// 说明: 异步 FIFO 功能仿真
//       - 使用小参数（DATA_WIDTH=8, ADDR_WIDTH=4, 深度16）加速仿真
//       - 写时钟 100MHz，读时钟 75MHz（跨时钟域）
//       - 场景：写满→full标志；顺序读验证数据；空→empty标志

module async_fifo_tb;

  localparam DW   = 8;
  localparam AW   = 4;   // 深度 2^4 = 16
  localparam DEPTH = (1 << AW);

  // 写时钟 100MHz (10ns), 读时钟 75MHz (~13.3ns)
  localparam WR_HALF = 5;
  localparam RD_HALF = 7;

  reg         reset;
  reg         wrclk, rdclk;
  reg         wren,  rden;
  reg  [DW-1:0] wrdata;
  wire [DW-1:0] rddata;
  wire          full, almost_full, empty;
  wire [AW:0]   wrusedw, rdusedw;

  async_fifo #(
    .DATA_WIDTH(DW),
    .ADDR_WIDTH(AW),
    .FULL_AHEAD(1),
    .SHOWAHEAD_EN(0)
  ) dut (
    .reset      (reset),
    .wrclk      (wrclk),
    .wren       (wren),
    .wrdata     (wrdata),
    .full       (full),
    .almost_full(almost_full),
    .wrusedw    (wrusedw),
    .rdclk      (rdclk),
    .rden       (rden),
    .rddata     (rddata),
    .empty      (empty),
    .rdusedw    (rdusedw)
  );

  // 时钟生成
  initial wrclk = 0;
  always #WR_HALF wrclk = ~wrclk;
  initial rdclk = 0;
  always #RD_HALF rdclk = ~rdclk;

  integer err = 0;
  integer i;
  reg [DW-1:0] exp_data [0:DEPTH-1];

  initial begin
    $dumpfile("async_fifo_tb.vcd");
    $dumpvars(0, async_fifo_tb);

    reset  = 1;
    wren   = 0;
    rden   = 0;
    wrdata = 0;

    repeat(5) @(posedge wrclk);
    reset = 0;
    repeat(3) @(posedge wrclk);

    // ── 场景1：写入 DEPTH 个数据直到 full ────────────────
    $display("[场景1] 顺序写入 %0d 个数据", DEPTH);
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(negedge wrclk);
      if (!full) begin
        wren   <= 1'b1;
        wrdata <= i[DW-1:0];
        exp_data[i] = i[DW-1:0];
      end else begin
        $display("[INFO] full at i=%0d", i);
      end
      @(posedge wrclk); #1;
    end
    @(negedge wrclk); wren <= 0;
    repeat(5) @(posedge wrclk);

    if (full)
      $display("[PASS] full 标志正确拉高");
    else begin
      $display("[FAIL] 写满后 full 未拉高");
      err = err + 1;
    end

    // ── 场景2：顺序读出，验证数据 ─────────────────────────
    $display("[场景2] 顺序读出并验证数据");
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(negedge rdclk);
      if (!empty) begin
        rden <= 1'b1;
      end
      @(posedge rdclk); #1;
      @(negedge rdclk);
      rden <= 1'b0;
      @(posedge rdclk); #1;
      if (rddata !== exp_data[i]) begin
        $display("[FAIL] 第%0d个数据: 期望0x%02h 实际0x%02h", i, exp_data[i], rddata);
        err = err + 1;
      end
    end
    repeat(10) @(posedge rdclk);

    if (empty)
      $display("[PASS] empty 标志正确拉高");
    else begin
      $display("[FAIL] 读空后 empty 未拉高");
      err = err + 1;
    end

    // ── 场景3：同时读写（wren=1, rden=1）─────────────────
    $display("[场景3] 同时读写验证");
    @(negedge wrclk);
    wren   <= 1'b1;
    wrdata <= 8'hAB;
    @(posedge wrclk);
    @(negedge wrclk); wren <= 0;
    repeat(10) @(posedge rdclk);

    @(negedge rdclk); rden <= 1'b1;
    @(posedge rdclk); #1;
    @(negedge rdclk); rden <= 0;
    @(posedge rdclk); #1;
    if (rddata === 8'hAB)
      $display("[PASS] 同时读写：读出 0x%02h", rddata);
    else begin
      $display("[FAIL] 同时读写：期望 0xAB，实际 0x%02h", rddata);
      err = err + 1;
    end

    repeat(10) @(posedge wrclk);

    if (err == 0)
      $display("[RESULT] async_fifo 全部测试通过！");
    else
      $display("[RESULT] async_fifo 存在 %0d 个错误", err);

    $finish;
  end

  initial begin
    #500_000;
    $display("[TIMEOUT] async_fifo 仿真超时");
    $finish;
  end
endmodule
