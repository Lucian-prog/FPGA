`timescale 1ns/1ps

//=============================================================================
// axi_mem_slave —— AXI4 memory 模型（AR/R + AW/W/B 从机，纯仿真模型）
//
// Phase 3 完整版：读侧（P2）+ 写侧，读写线程共用同一 mem 存储，
// 可同时充当 DMA 的源区和目的区（端到端 mem diff 验证的基础）。
//
// 读侧职责（P2 原有）：
//   承接 axi_rd_ch 读请求，逐 beat 返回 R 数据，RLAST 末拍。
// 写侧职责（P3 新增）：
//   承接 axi_wr_ch 写请求：AW 握手 -> 逐 beat 收 W 写入 mem -> 返回 B 响应。
//
// TB 可配置（公开变量，层次引用读写）：
//   ar_ready_delay —— ARREADY 插入延迟拍数（读地址反压）
//   err_addr/err_en —— 读侧错误注入：beat 地址命中 -> RRESP=SLVERR
//   aw_ready_delay —— AWREADY 插入延迟拍数（写地址反压）
//   w_ready_gap    —— 每 W beat 前的反压拍数（写数据反压；0=背靠背）
//   wr_err_addr/wr_err_en —— 写侧错误注入：AW 地址命中 -> BRESP=SLVERR
//
// TB 可采样：
//   last_ar*/last_aw* —— 最近一次 AR/AW 信息锁存
//   ar_xfer_cnt/aw_xfer_cnt —— 已服务的读/写 burst 事务数
//
// 竞争规避：所有输出激励在 negedge clk 变化，握手判定在 posedge clk
// 唤醒后以"沿前稳定值"判定。W 数据写入 mem 在握手沿唤醒后立即执行
// （阻塞赋值，早于下一拍任何采样）。
//=============================================================================

module axi_mem_slave #(
  parameter int DEPTH = 1024            // 存储深度（word 数，2 的幂）
) (
  input  logic        clk,
  input  logic        rst_n,
  // 读侧：AR 通道
  input  logic [31:0] s_axi_araddr,
  input  logic [7:0]  s_axi_arlen,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [2:0]  s_axi_arsize,     // 模型不检查，保留
  input  logic [1:0]  s_axi_arburst,    // 模型不检查，保留
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,
  // 读侧：R 通道
  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rlast,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready,
  // 写侧：AW 通道
  input  logic [31:0] s_axi_awaddr,
  input  logic [7:0]  s_axi_awlen,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [2:0]  s_axi_awsize,     // 模型不检查，保留
  input  logic [1:0]  s_axi_awburst,    // 模型不检查，保留
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,
  // 写侧：W 通道
  input  logic [31:0] s_axi_wdata,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [3:0]  s_axi_wstrb,      // DMA 恒全 1，模型按整 word 写
  input  logic        s_axi_wlast,
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,
  // 写侧：B 通道
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready
);

  import dma_pkg::*;

  //---------------------------------------------------------------------------
  // 存储与索引
  //---------------------------------------------------------------------------
  localparam int AW = $clog2(DEPTH);    // word 索引位宽

  logic [31:0] mem [DEPTH];             // 公开存储，TB 预填 / 比对 / 波形观测

  function automatic logic [AW-1:0] word_index(input logic [31:0] addr);
    word_index = addr[AW+1:2];
  endfunction

  //---------------------------------------------------------------------------
  // 公开配置变量（TB 层次引用读写）
  //---------------------------------------------------------------------------
  int          ar_ready_delay = 0;
  logic [31:0] err_addr       = 32'hFFFF_FFFC;  // 读侧注入地址（默认不命中）
  bit          err_en         = 1'b0;

  int          aw_ready_delay = 0;               // 写地址反压拍数
  int          w_ready_gap    = 0;               // 写数据反压：每 beat 前拍数
  logic [31:0] wr_err_addr    = 32'hFFFF_FFFC;   // 写侧注入地址（按 AW 匹配）
  bit          wr_err_en      = 1'b0;

  //---------------------------------------------------------------------------
  // 公开采样变量（TB 用例校验）
  //---------------------------------------------------------------------------
  logic [31:0] last_araddr, last_awaddr;
  logic [7:0]  last_arlen,  last_awlen;
  logic [2:0]  last_arsize, last_awsize;
  logic [1:0]  last_arburst, last_awburst;
  int          ar_xfer_cnt = 0;    // 已完成读 burst 数
  int          aw_xfer_cnt = 0;    // 已完成写 burst 数（B 响应后计数）

  //---------------------------------------------------------------------------
  // 公开 task：TB 预填存储
  //---------------------------------------------------------------------------
  task automatic mem_write(input logic [31:0] addr, input logic [31:0] data);
    mem[word_index(addr)] = data;
  endtask

  initial begin
    for (int i = 0; i < DEPTH; i++) begin
      mem[i] = 32'h0;
    end
  end

  //===========================================================================
  // 读线程（P2 原有逻辑，增加 ar_xfer_cnt 计数）
  //===========================================================================
  logic [31:0] beat_addr;

  initial begin
    s_axi_arready = 1'b0;
    s_axi_rvalid  = 1'b0;
    s_axi_rdata   = 32'h0;
    s_axi_rresp   = AXI_RESP_OKAY;
    s_axi_rlast   = 1'b0;
    last_araddr   = 32'h0;
    last_arlen    = 8'h0;
    last_arsize   = 3'b000;
    last_arburst  = 2'b00;

    forever begin
      wait (rst_n === 1'b1);

      // ---- AR 相位 ----
      while (s_axi_arvalid !== 1'b1) @(posedge clk);
      last_araddr  = s_axi_araddr;
      last_arlen   = s_axi_arlen;
      last_arsize  = s_axi_arsize;
      last_arburst = s_axi_arburst;

      if (ar_ready_delay > 0) begin
        repeat (ar_ready_delay) @(posedge clk);
      end

      @(negedge clk);
      s_axi_arready = 1'b1;
      @(posedge clk);              // AR 握手沿
      @(negedge clk);
      s_axi_arready = 1'b0;
      ar_xfer_cnt++;

      // ---- R 相位 ----
      for (int i = 0; i <= last_arlen; i++) begin
        beat_addr    = last_araddr + i * 4;
        s_axi_rdata  = mem[word_index(beat_addr)];
        s_axi_rresp  = (err_en && (beat_addr == err_addr)) ? AXI_RESP_SLVERR
                                                           : AXI_RESP_OKAY;
        s_axi_rlast  = (i == last_arlen);
        s_axi_rvalid = 1'b1;
        while (s_axi_rready !== 1'b1) @(posedge clk);
        if (i < last_arlen) @(negedge clk);
      end
      @(negedge clk);
      s_axi_rvalid = 1'b0;
      s_axi_rlast  = 1'b0;
      s_axi_rresp  = AXI_RESP_OKAY;
    end
  end

  //===========================================================================
  // 写线程（P3 新增）
  //   AW 相位：锁存 AW 信息 -> 插 aw_ready_delay -> 单拍 AWREADY 握手
  //   W  相位：每 beat 先撤 WREADY 插 w_ready_gap 拍反压 -> 拉高 -> 等
  //            WVALID 出现的 posedge（双高即握手）-> 写入 mem
  //   B  相位：BRESP 按注入配置，BVALID 保持到 BREADY
  //===========================================================================
  logic wr_slv;   // 本写事务是否注入 SLVERR（按 AW 地址匹配）

  initial begin
    s_axi_awready = 1'b0;
    s_axi_wready  = 1'b0;
    s_axi_bresp   = AXI_RESP_OKAY;
    s_axi_bvalid  = 1'b0;
    last_awaddr   = 32'h0;
    last_awlen    = 8'h0;
    last_awsize   = 3'b000;
    last_awburst  = 2'b00;

    forever begin
      wait (rst_n === 1'b1);

      // ---- AW 相位 ----
      while (s_axi_awvalid !== 1'b1) @(posedge clk);
      last_awaddr  = s_axi_awaddr;
      last_awlen   = s_axi_awlen;
      last_awsize  = s_axi_awsize;
      last_awburst = s_axi_awburst;
      wr_slv       = wr_err_en && (last_awaddr == wr_err_addr);

      if (aw_ready_delay > 0) begin
        repeat (aw_ready_delay) @(posedge clk);
      end

      @(negedge clk);
      s_axi_awready = 1'b1;
      @(posedge clk);              // AW 握手沿
      @(negedge clk);
      s_axi_awready = 1'b0;

      // ---- W 相位 ----
      for (int i = 0; i <= last_awlen; i++) begin
        // 反压窗口：WREADY 拉低 w_ready_gap 拍
        @(negedge clk);
        s_axi_wready = 1'b0;
        if (w_ready_gap > 0) begin
          repeat (w_ready_gap) @(posedge clk);
        end
        // 拉高 WREADY，等 WVALID 出现的握手沿（双高即握手）
        @(negedge clk);
        s_axi_wready = 1'b1;
        forever begin
          @(posedge clk);
          if (s_axi_wvalid === 1'b1) break;   // 该沿 WVALID&&WREADY -> 握手
        end
        // 握手拍唤醒后写入（wstrb 恒全 1，按整 word 写）
        mem[word_index(last_awaddr + i * 4)] = s_axi_wdata;
      end
      @(negedge clk);
      s_axi_wready = 1'b0;

      // ---- B 相位 ----
      s_axi_bresp  = wr_slv ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
      s_axi_bvalid = 1'b1;
      while (s_axi_bready !== 1'b1) @(posedge clk);
      @(negedge clk);
      s_axi_bvalid = 1'b0;
      s_axi_bresp  = AXI_RESP_OKAY;
      aw_xfer_cnt++;
    end
  end

endmodule
