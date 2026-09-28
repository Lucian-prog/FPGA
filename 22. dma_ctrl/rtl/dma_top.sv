//=============================================================================
// dma_top.sv —— DMA 控制器顶层（Phase 4 集成封装）
//
// 对外接口：
//   1. AXI4-Lite slave（s_axil_*）：CPU 配置/状态访问（ dma_regs ）
//   2. AXI4 master 读侧（m_axi_ar*/r*）+ 写侧（m_axi_aw*/w*/b*）：内存搬运
//   3. irq_tc_o / irq_te_o：传输完成 / 错误 中断（电平，ICR 写 1 清除）
//
// 内部结构（计划 §3/§4）：
//   dma_regs  —— 寄存器组 + AXI4-Lite 从机 + 中断标志（含 irq 逻辑，
//                计划原定的独立 irq_gen 职责已并入，不再单设模块）
//   dma_ctrl  —— 主 FSM：burst 切分 / 4KB 边界 / 读写游标 / 错误处理
//   axi_rd_ch —— AXI4 读 master（AR/R），数据入 FIFO
//   axi_wr_ch —— AXI4 写 master（AW/W/B），数据出 FIFO
//   dma_fifo  —— 16x32 同步缓冲，解耦读写反压
//
// 时钟/复位：单时钟域；rst_n 低有效异步复位（外部提供 async assert /
// sync deassert 的复位，模块内部各子模块均为异步复位）。
//=============================================================================

module dma_top (
  input  logic        clk,
  input  logic        rst_n,          // 低有效异步复位
  // AXI4-Lite slave（配置口）
  input  logic [31:0] s_axil_awaddr,
  input  logic [2:0]  s_axil_awprot,
  input  logic        s_axil_awvalid,
  output logic        s_axil_awready,
  input  logic [31:0] s_axil_wdata,
  input  logic [3:0]  s_axil_wstrb,
  input  logic        s_axil_wvalid,
  output logic        s_axil_wready,
  output logic [1:0]  s_axil_bresp,
  output logic        s_axil_bvalid,
  input  logic [31:0] s_axil_araddr,
  input  logic        s_axil_arvalid,
  output logic        s_axil_arready,
  output logic [31:0] s_axil_rdata,
  output logic [1:0]  s_axil_rresp,
  output logic        s_axil_rvalid,
  // AXI4 master：读侧（AR/R）
  output logic [31:0] m_axi_araddr,
  output logic [7:0]  m_axi_arlen,
  output logic [2:0]  m_axi_arsize,
  output logic [1:0]  m_axi_arburst,
  output logic        m_axi_arvalid,
  input  logic        m_axi_arready,
  input  logic [31:0] m_axi_rdata,
  input  logic [1:0]  m_axi_rresp,
  input  logic        m_axi_rlast,
  input  logic        m_axi_rvalid,
  output logic        m_axi_rready,
  // AXI4 master：写侧（AW/W/B）
  output logic [31:0] m_axi_awaddr,
  output logic [7:0]  m_axi_awlen,
  output logic [2:0]  m_axi_awsize,
  output logic [1:0]  m_axi_awburst,
  output logic        m_axi_awvalid,
  input  logic        m_axi_awready,
  output logic [31:0] m_axi_wdata,
  output logic [3:0]  m_axi_wstrb,
  output logic        m_axi_wlast,
  output logic        m_axi_wvalid,
  input  logic        m_axi_wready,
  input  logic [1:0]  m_axi_bresp,
  input  logic        m_axi_bvalid,
  output logic        m_axi_bready,
  // 中断
  output logic        irq_tc_o,       // 传输完成（TC 标志 & IE_TC）
  output logic        irq_te_o        // 传输错误（TE 标志 & IE_TE）
);

  //---------------------------------------------------------------------------
  // 内部连线：dma_regs <-> dma_ctrl
  //---------------------------------------------------------------------------
  logic        start_pulse;
  logic [31:0] cfg_src, cfg_dst, cfg_len;
  logic        cfg_en, cfg_ie_tc, cfg_ie_te;
  logic [2:0]  cfg_burst;
  logic        sts_busy, sts_done;
  logic [1:0]  sts_errcode;
  logic        tc_event, te_event;

  //---------------------------------------------------------------------------
  // 内部连线：dma_ctrl <-> axi_rd_ch / axi_wr_ch
  //---------------------------------------------------------------------------
  logic        rd_req_valid, rd_req_ready;
  logic [31:0] rd_addr;
  logic [7:0]  rd_beats;
  logic        rd_done, rd_err;
  logic [1:0]  rd_errcode;

  logic        wr_req_valid, wr_req_ready;
  logic [31:0] wr_addr;
  logic [7:0]  wr_beats;
  logic        wr_done, wr_err;
  logic [1:0]  wr_errcode;

  //---------------------------------------------------------------------------
  // 内部连线：FIFO（rd_ch 入队 / wr_ch 出队）
  //---------------------------------------------------------------------------
  logic        fifo_in_valid, fifo_in_ready;
  logic [31:0] fifo_in_data;
  logic        fifo_out_valid, fifo_out_ready;
  logic [31:0] fifo_out_data;

  //---------------------------------------------------------------------------
  // 子模块例化
  //---------------------------------------------------------------------------
  dma_regs u_regs (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_axil_awaddr  (s_axil_awaddr),
    .s_axil_awprot  (s_axil_awprot),
    .s_axil_awvalid (s_axil_awvalid),
    .s_axil_awready (s_axil_awready),
    .s_axil_wdata   (s_axil_wdata),
    .s_axil_wstrb   (s_axil_wstrb),
    .s_axil_wvalid  (s_axil_wvalid),
    .s_axil_wready  (s_axil_wready),
    .s_axil_bresp   (s_axil_bresp),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_araddr  (s_axil_araddr),
    .s_axil_arvalid (s_axil_arvalid),
    .s_axil_arready (s_axil_arready),
    .s_axil_rdata   (s_axil_rdata),
    .s_axil_rresp   (s_axil_rresp),
    .s_axil_rvalid  (s_axil_rvalid),
    .src_o          (cfg_src),
    .dst_o          (cfg_dst),
    .len_o          (cfg_len),
    .ctrl_en_o      (cfg_en),
    .ctrl_burst_o   (cfg_burst),
    .ctrl_ie_tc_o   (cfg_ie_tc),
    .ctrl_ie_te_o   (cfg_ie_te),
    .busy_i         (sts_busy),
    .done_i         (sts_done),
    .errcode_i      (sts_errcode),
    .tc_event_i     (tc_event),
    .te_event_i     (te_event),
    .start_pulse_o  (start_pulse),
    .irq_tc_o       (irq_tc_o),
    .irq_te_o       (irq_te_o)
  );

  dma_ctrl u_ctrl (
    .clk            (clk),
    .rst_n          (rst_n),
    .start_pulse_i  (start_pulse),
    .src_i          (cfg_src),
    .dst_i          (cfg_dst),
    .len_i          (cfg_len),
    .burst_i        (cfg_burst),
    .rd_req_valid_o (rd_req_valid),
    .rd_req_ready_i (rd_req_ready),
    .rd_addr_o      (rd_addr),
    .rd_beats_o     (rd_beats),
    .rd_done_i      (rd_done),
    .rd_err_i       (rd_err),
    .rd_errcode_i   (rd_errcode),
    .wr_req_valid_o (wr_req_valid),
    .wr_req_ready_i (wr_req_ready),
    .wr_addr_o      (wr_addr),
    .wr_beats_o     (wr_beats),
    .wr_done_i      (wr_done),
    .wr_err_i       (wr_err),
    .wr_errcode_i   (wr_errcode),
    .busy_o         (sts_busy),
    .done_o         (sts_done),
    .errcode_o      (sts_errcode),
    .tc_event_o     (tc_event),
    .te_event_o     (te_event)
  );

  axi_rd_ch u_rd (
    .clk             (clk),
    .rst_n           (rst_n),
    .rd_req_valid_i  (rd_req_valid),
    .rd_req_ready_o  (rd_req_ready),
    .rd_addr_i       (rd_addr),
    .rd_beats_i      (rd_beats),
    .rd_done_o       (rd_done),
    .rd_err_o        (rd_err),
    .rd_errcode_o    (rd_errcode),
    .m_axi_araddr    (m_axi_araddr),
    .m_axi_arlen     (m_axi_arlen),
    .m_axi_arsize    (m_axi_arsize),
    .m_axi_arburst   (m_axi_arburst),
    .m_axi_arvalid   (m_axi_arvalid),
    .m_axi_arready   (m_axi_arready),
    .m_axi_rdata     (m_axi_rdata),
    .m_axi_rresp     (m_axi_rresp),
    .m_axi_rlast     (m_axi_rlast),
    .m_axi_rvalid    (m_axi_rvalid),
    .m_axi_rready    (m_axi_rready),
    .fifo_in_valid_o (fifo_in_valid),
    .fifo_in_ready_i (fifo_in_ready),
    .fifo_in_data_o  (fifo_in_data)
  );

  axi_wr_ch u_wr (
    .clk              (clk),
    .rst_n            (rst_n),
    .wr_req_valid_i   (wr_req_valid),
    .wr_req_ready_o   (wr_req_ready),
    .wr_addr_i        (wr_addr),
    .wr_beats_i       (wr_beats),
    .wr_done_o        (wr_done),
    .wr_err_o         (wr_err),
    .wr_errcode_o     (wr_errcode),
    .m_axi_awaddr     (m_axi_awaddr),
    .m_axi_awlen      (m_axi_awlen),
    .m_axi_awsize     (m_axi_awsize),
    .m_axi_awburst    (m_axi_awburst),
    .m_axi_awvalid    (m_axi_awvalid),
    .m_axi_awready    (m_axi_awready),
    .m_axi_wdata      (m_axi_wdata),
    .m_axi_wstrb      (m_axi_wstrb),
    .m_axi_wlast      (m_axi_wlast),
    .m_axi_wvalid     (m_axi_wvalid),
    .m_axi_wready     (m_axi_wready),
    .m_axi_bresp      (m_axi_bresp),
    .m_axi_bvalid     (m_axi_bvalid),
    .m_axi_bready     (m_axi_bready),
    .fifo_out_valid_i (fifo_out_valid),
    .fifo_out_ready_o (fifo_out_ready),
    .fifo_out_data_i  (fifo_out_data)
  );

  dma_fifo u_fifo (
    .clk       (clk),
    .rst_n     (rst_n),
    .in_valid  (fifo_in_valid),
    .in_ready  (fifo_in_ready),
    .in_data   (fifo_in_data),
    .out_valid (fifo_out_valid),
    .out_ready (fifo_out_ready),
    .out_data  (fifo_out_data)
  );

endmodule
