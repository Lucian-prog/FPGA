`timescale 1ns/1ps

//=============================================================================
// axi_lite_bfm —— AXI4-Lite 主侧 BFM（简化协议版，适配 dma_regs）
//
// 协议简化点（与 dma_regs DUT 约定一致）：
//   1. 无 bready/rready 端口：bvalid/rvalid 为单拍脉冲，BFM 直接等待采样
//   2. awready/wready/arready 预期常高，但仍按标准握手语义等待
//
// 竞争规避：所有激励在 negedge clk 变化（DUT 不在 negedge 采样），
// 所有握手/响应检查在 posedge clk 唤醒后读取（读到的是沿前建立的稳定值，
// 因为 DUT 寄存器用非阻塞赋值更新），保证无采样竞争。
//
// 公开变量（TB 可直接读写）：
//   wr_resp      最近一次写通道响应码（超时时无效）
//   rd_resp      最近一次读通道响应码（超时时无效）
//   wr_timeout   写等待 bvalid 超时标志（1 = 未在限定拍数内收到响应）
//   rd_timeout   读等待 rvalid 超时标志
//   write_gap    每次写操作前后的空闲拍数（默认 0）
//   resp_timeout 等待 bvalid/rvalid 的最大拍数（默认 500）
//=============================================================================

module axi_lite_bfm (
  input  logic        clk,
  input  logic        rst_n,
  // AXI4-Lite：AW 通道（主 -> 从）
  output logic [31:0] s_axil_awaddr,
  output logic [2:0]  s_axil_awprot,
  output logic        s_axil_awvalid,
  input  logic        s_axil_awready,
  // AXI4-Lite：W 通道（主 -> 从）
  output logic [31:0] s_axil_wdata,
  output logic [3:0]  s_axil_wstrb,
  output logic        s_axil_wvalid,
  input  logic        s_axil_wready,
  // AXI4-Lite：B 通道（从 -> 主，简化协议无 bready）
  input  logic [1:0]  s_axil_bresp,
  input  logic        s_axil_bvalid,
  // AXI4-Lite：AR 通道（主 -> 从）
  output logic [31:0] s_axil_araddr,
  output logic        s_axil_arvalid,
  input  logic        s_axil_arready,
  // AXI4-Lite：R 通道（从 -> 主，简化协议无 rready）
  input  logic [31:0] s_axil_rdata,
  input  logic [1:0]  s_axil_rresp,
  input  logic        s_axil_rvalid
);

  //---------------------------------------------------------------------------
  // 公开状态变量（TB 通过层次引用读取/配置）
  //---------------------------------------------------------------------------
  logic [1:0] wr_resp;            // 最近一次写响应
  logic [1:0] rd_resp;            // 最近一次读响应
  logic       wr_timeout;         // 写响应等待超时标志
  logic       rd_timeout;         // 读响应等待超时标志
  int         write_gap    = 0;   // 写操作前后空闲拍数
  int         resp_timeout = 500; // 响应等待最大拍数

  //---------------------------------------------------------------------------
  // 输出初始化 + 复位保护
  // 复位期间强制 valid 拉低，防止异常流程下残留有效握手电平
  //---------------------------------------------------------------------------
  initial begin
    s_axil_awaddr  = 32'b0;
    s_axil_awprot  = 3'b000;
    s_axil_awvalid = 1'b0;
    s_axil_wdata   = 32'b0;
    s_axil_wstrb   = 4'b0000;
    s_axil_wvalid  = 1'b0;
    s_axil_araddr  = 32'b0;
    s_axil_arvalid = 1'b0;
    wr_resp        = 2'b00;
    rd_resp        = 2'b00;
    wr_timeout     = 1'b0;
    rd_timeout     = 1'b0;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s_axil_awvalid <= 1'b0;
      s_axil_wvalid  <= 1'b0;
      s_axil_arvalid <= 1'b0;
    end
    // else：正常工作期由任务驱动，此处不赋值（保持）
  end

  //---------------------------------------------------------------------------
  // axil_write —— 单笔 32bit 写
  // 流程：[前置 idle write_gap 拍] -> negedge 驱动 aw/w（valid 拉高后握手
  //       完成前不撤回）-> posedge 等待两通道各自握手 -> negedge 撤 valid ->
  //       posedge 等待 bvalid 单拍脉冲并采样 bresp -> [后置 idle write_gap 拍]
  //---------------------------------------------------------------------------
  task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
    int wait_cnt;
    bit aw_done;
    bit w_done;

    // 前置空闲拍（消费 write_gap）
    if (write_gap > 0) repeat (write_gap) @(posedge clk);

    // negedge 驱动激励，避开 DUT 的 posedge 采样沿
    @(negedge clk);
    s_axil_awaddr  = addr;
    s_axil_awprot  = 3'b000;
    s_axil_awvalid = 1'b1;
    s_axil_wdata   = data;
    s_axil_wstrb   = 4'b1111;
    s_axil_wvalid  = 1'b1;

    // 等待 AW / W 双通道各自握手完成（采样沿 ready 为高即该沿握手成功）
    aw_done = 1'b0;
    w_done  = 1'b0;
    while (!aw_done || !w_done) begin
      @(posedge clk);
      if (!aw_done && s_axil_awready === 1'b1) aw_done = 1'b1;
      if (!w_done  && s_axil_wready  === 1'b1) w_done  = 1'b1;
    end

    // 握手完成后的半个周期撤回 valid（negedge 驱动，DUT 下个采样沿看到低）
    @(negedge clk);
    s_axil_awvalid = 1'b0;
    s_axil_wvalid  = 1'b0;

    // 等待 bvalid 单拍脉冲（带超时保护）
    wr_timeout = 1'b0;
    wait_cnt   = 0;
    while (s_axil_bvalid !== 1'b1 && wait_cnt < resp_timeout) begin
      @(posedge clk);
      wait_cnt = wait_cnt + 1;
    end
    if (s_axil_bvalid === 1'b1) begin
      wr_resp = s_axil_bresp;   // 采样写响应
    end else begin
      wr_timeout = 1'b1;        // 超时：响应无效
      wr_resp    = 2'bxx;
    end

    // 后置空闲拍（消费 write_gap）
    if (write_gap > 0) repeat (write_gap) @(posedge clk);
  endtask

  //---------------------------------------------------------------------------
  // axil_read —— 单笔 32bit 读
  // 流程：negedge 驱动 AR（valid 拉高后握手完成前不撤回）-> posedge 等待
  //       arready 握手 -> negedge 撤 valid -> posedge 等待 rvalid 单拍脉冲，
  //       采样 rdata/rresp（带超时保护）
  //---------------------------------------------------------------------------
  task automatic axil_read(input logic [31:0] addr, output logic [31:0] data);
    int wait_cnt;
    bit ar_done;

    // negedge 驱动 AR 通道
    @(negedge clk);
    s_axil_araddr  = addr;
    s_axil_arvalid = 1'b1;

    // 等待 AR 通道握手完成
    ar_done = 1'b0;
    while (!ar_done) begin
      @(posedge clk);
      if (s_axil_arready === 1'b1) ar_done = 1'b1;
    end

    // 握手完成后撤回 valid
    @(negedge clk);
    s_axil_arvalid = 1'b0;

    // 等待 rvalid 单拍脉冲（带超时保护）
    rd_timeout = 1'b0;
    wait_cnt   = 0;
    while (s_axil_rvalid !== 1'b1 && wait_cnt < resp_timeout) begin
      @(posedge clk);
      wait_cnt = wait_cnt + 1;
    end
    if (s_axil_rvalid === 1'b1) begin
      rd_resp = s_axil_rresp;
      data    = s_axil_rdata;
    end else begin
      rd_timeout = 1'b1;        // 超时：数据无效
      rd_resp    = 2'bxx;
      data       = 32'hxxxx_xxxx;
    end
  endtask

endmodule
