//-----------------------------------------------------------------------------
// Module: axi_wr_ch
// Description: AXI4 写通道 master（AW/W/B 通道），DMA 引擎写数据通路
//
// 与 axi_rd_ch 对称的设计，接口/时序风格一致：
//   clk / rst_n        - 时钟（上边沿）与低有效异步复位
//   wr_req_*           - DMA 引擎请求（valid/ready 握手，锁存地址与 beat 数）
//   wr_done/wr_err     - 完成或错误汇报，各 1 拍脉冲且互斥
//   wr_errcode         - dma_pkg::errcode_e 值，出错后保持至下次传输清零
//   m_axi_aw*          - AXI4 写地址通道（AWID 固定 0，不引出）
//   m_axi_w*           - AXI4 写数据通道（数据来源：外部 FIFO 出队侧）
//   m_axi_b*           - AXI4 写响应通道（BREADY 在 B 态拉高保持）
//   fifo_out_*         - FIFO 出队侧消费接口
//
// 设计要点:
//   - FSM：IDLE -> PUSH（AW 与 W 并行推）-> B（等写响应）-> IDLE。
//   - AWVALID 一经拉高保持到 AWREADY（死锁规避）；AW 与 W 同拍发起
//     （wr_req 握手后两者立即有效，符合 AXI 推荐）。
//   - W 通道与 FIFO 出队严格同步：WVALID 直通 fifo_out_valid（FIFO 不弹
//     则 WVALID 保持），WREADY 门控出队，w_fire == FIFO 弹出，一拍一 beat。
//   - 进入 B 态条件 = AW 已握手 && WLAST 已握手（AXI 规范：B 在 AW/W 全部
//     完成后返回；AWREADY 慢时 W 先推完仍在 PUSH 态等 AW）。
//   - BRESP 采样：SLVERR -> ERR_SLV；其余非 OKAY（DECERR/EXOKAY）->
//     ERR_RRESP（编码复用，语义为"响应码错误"，见 dma_pkg 注释）。
//   - done/err 脉冲在 B 握手次拍输出（与 rd_ch 风格一致）。
//-----------------------------------------------------------------------------
module axi_wr_ch (
  input  logic        clk,
  input  logic        rst_n,          // 低有效异步复位
  // DMA 引擎请求（valid/ready 握手）
  input  logic        wr_req_valid_i,
  output logic        wr_req_ready_o,
  input  logic [31:0] wr_addr_i,      // 写起始地址（word 对齐）
  input  logic [7:0]  wr_beats_i,     // beat 数 - 1（AWLEN 格式；0=SINGLE）
  // 完成/错误（各 1 拍脉冲，互斥）
  output logic        wr_done_o,
  output logic        wr_err_o,
  output logic [1:0]  wr_errcode_o,   // dma_pkg::errcode_e 值，出错后保持
  // AXI4 写地址通道（AWID 固定 0，不引出端口）
  output logic [31:0] m_axi_awaddr,
  output logic [7:0]  m_axi_awlen,
  output logic [2:0]  m_axi_awsize,
  output logic [1:0]  m_axi_awburst,
  output logic        m_axi_awvalid,
  input  logic        m_axi_awready,
  // AXI4 写数据通道
  output logic [31:0] m_axi_wdata,
  output logic [3:0]  m_axi_wstrb,
  output logic        m_axi_wlast,
  output logic        m_axi_wvalid,
  input  logic        m_axi_wready,
  // AXI4 写响应通道
  input  logic [1:0]  m_axi_bresp,
  input  logic        m_axi_bvalid,
  output logic        m_axi_bready,
  // FIFO 出队侧（外部为 dma_fifo）
  input  logic        fifo_out_valid_i,
  output logic        fifo_out_ready_o,
  input  logic [31:0] fifo_out_data_i
);

  import dma_pkg::*;

  // ---------------------------------------------------------------------
  // 状态与常量
  // ---------------------------------------------------------------------
  localparam logic [1:0] S_IDLE = 2'b00;  // 空闲，可接受新请求
  localparam logic [1:0] S_PUSH = 2'b01;  // 推 AW + W beats
  localparam logic [1:0] S_B    = 2'b10;  // 等待写响应

  // dma_pkg 未定义 DECERR，按 AXI4 标准补充（与 axi_rd_ch 一致）
  localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

  // ---------------------------------------------------------------------
  // 内部信号
  // ---------------------------------------------------------------------
  logic [1:0]  state_q, state_n;      // FSM 现态 / 次态
  logic [31:0] addr_lat_q;            // 锁存的写起始地址
  logic [7:0]  beats_lat_q;           // 锁存的 AWLEN
  logic [7:0]  beat_cnt_q;            // 已完成握手的 W beat 计数
  logic        aw_done_q;             // AW 通道已握手完成标志
  logic [1:0]  errcode_q, errcode_n;  // 错误码

  logic        req_fire, w_fire, aw_fire;

  // ---------------------------------------------------------------------
  // DMA 请求握手（仅 IDLE 态可接受）
  // ---------------------------------------------------------------------
  assign wr_req_ready_o = (state_q == S_IDLE);
  assign req_fire       = wr_req_valid_i && wr_req_ready_o;

  // ---------------------------------------------------------------------
  // AW 通道（ID 固定 0；SIZE=4 字节、BURST=INCR 固定配置）
  // AWVALID 在 PUSH 态拉高，握手后撤回（aw_done_q 门控），拉高期间稳定
  // ---------------------------------------------------------------------
  assign m_axi_awaddr  = addr_lat_q;
  assign m_axi_awlen   = beats_lat_q;
  assign m_axi_awsize  = 3'b010;   // 2^2 = 4 字节
  assign m_axi_awburst = 2'b01;    // INCR
  assign m_axi_awvalid = (state_q == S_PUSH) && !aw_done_q;

  assign aw_fire = m_axi_awvalid && m_axi_awready;

  // ---------------------------------------------------------------------
  // W 通道 <-> FIFO 出队侧（仅 PUSH 态有效，组合直通）
  //   WVALID 直通 FIFO 出队 valid：FIFO 有数则 WVALID=1 且数据稳定，
  //   WREADY=0 时 FIFO 不弹 -> WVALID 自然保持（AXI 死锁规避）
  //   WREADY 门控 FIFO 出队：w_fire 拍 = FIFO 弹出拍，一拍一 beat
  // ---------------------------------------------------------------------
  assign m_axi_wvalid    = (state_q == S_PUSH) && fifo_out_valid_i;
  assign m_axi_wdata     = fifo_out_data_i;
  assign m_axi_wstrb     = 4'b1111;
  assign m_axi_wlast     = (beat_cnt_q == beats_lat_q);
  assign fifo_out_ready_o = (state_q == S_PUSH) && m_axi_wready;

  assign w_fire = m_axi_wvalid && m_axi_wready;

  // ---------------------------------------------------------------------
  // B 通道：BREADY 在 B 态拉高保持（BVALID 到来当拍即完成握手）
  // ---------------------------------------------------------------------
  assign m_axi_bready = (state_q == S_B);

  assign wr_errcode_o = errcode_q;

  // ---------------------------------------------------------------------
  // 次态逻辑（组合）
  //   PUSH -> B：AW 已握手 && 本拍 WLAST 握手（W 侧最后一个 beat 完成）
  //   B    -> IDLE：BVALID 出现（BREADY 已高，当拍握手）
  // ---------------------------------------------------------------------
  always_comb begin
    state_n = state_q;  // 默认保持
    case (state_q)
      S_IDLE: if (req_fire)                                state_n = S_PUSH;
      S_PUSH: if (aw_done_q && w_fire && m_axi_wlast)      state_n = S_B;
      S_B:    if (m_axi_bvalid)                            state_n = S_IDLE;
      default:                                             state_n = S_IDLE;
    endcase
  end

  // ---------------------------------------------------------------------
  // 错误码下一值（组合）：请求拍清零；B 态采样 BRESP
  // ---------------------------------------------------------------------
  always_comb begin
    errcode_n = errcode_q;
    if (req_fire) begin
      errcode_n = ERR_NONE;
    end else if (state_q == S_B && m_axi_bvalid && errcode_q == ERR_NONE) begin
      if (m_axi_bresp == AXI_RESP_SLVERR) begin
        errcode_n = ERR_SLV;
      end else if (m_axi_bresp != AXI_RESP_OKAY) begin
        errcode_n = ERR_RRESP;  // DECERR/EXOKAY 等其余响应
      end
    end
  end

  // ---------------------------------------------------------------------
  // 状态 / 锁存 / 计数 / 标志（异步复位，复位清零）
  // ---------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q     <= S_IDLE;
      addr_lat_q  <= '0;
      beats_lat_q <= '0;
      beat_cnt_q  <= '0;
      aw_done_q   <= 1'b0;
      errcode_q   <= ERR_NONE;
    end else begin
      state_q   <= state_n;
      errcode_q <= errcode_n;
      if (req_fire) begin
        addr_lat_q  <= wr_addr_i;    // 锁存本次传输参数
        beats_lat_q <= wr_beats_i;
        beat_cnt_q  <= '0;
        aw_done_q   <= 1'b0;
      end else begin
        if (aw_fire) aw_done_q <= 1'b1;       // AW 握手完成
        if (w_fire)  beat_cnt_q <= beat_cnt_q + 1'b1;
      end
    end
  end

  // ---------------------------------------------------------------------
  // 完成/错误脉冲（寄存输出，与 rd_ch 风格一致）
  //   B 握手（BVALID 出现）次拍输出，与 state 回 IDLE 同拍
  // ---------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_done_o <= 1'b0;
      wr_err_o  <= 1'b0;
    end else if (state_q == S_B && state_n == S_IDLE) begin
      wr_done_o <= (errcode_n == ERR_NONE);
      wr_err_o  <= (errcode_n != ERR_NONE);
    end else begin
      wr_done_o <= 1'b0;
      wr_err_o  <= 1'b0;
    end
  end

endmodule
