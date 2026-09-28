//-----------------------------------------------------------------------------
// Module: axi_rd_ch
// Description: AXI4 读通道 master（AR/R 通道），DMA 引擎读数据通路
//
// Parameters: 无（位宽固定 32 位数据 / 32 位地址，与端口契约一致）
//
// Interfaces:
//   clk / rst_n        - 时钟（上边沿）与低有效异步复位
//   rd_req_*           - DMA 引擎请求（valid/ready 握手，锁存地址与 beat 数）
//   rd_done/rd_err     - 完成或错误汇报，各 1 拍脉冲且互斥
//   rd_errcode         - dma_pkg::errcode_e 值，出错后保持至下次传输清零
//   m_axi_ar*          - AXI4 读地址通道（ARID 固定为 0，按契约不引出端口）
//   m_axi_r*           - AXI4 读数据通道
//   fifo_in_*          - 读数据入队侧，外部为 dma_fifo（DEPTH=16 >= beats+1 不会满）
//
// 设计要点:
//   - 三段式 FSM：IDLE -> AR（发 AR）-> RDATA（收 R beat）-> IDLE，
//     RLAST 握手成功后下一拍输出 done/err 单拍脉冲（脉冲拍已回 IDLE，
//     rd_req_ready_o 已可接收新请求）。
//   - ARVALID 一旦拉高保持至 ARREADY（AXI 死锁规避，VALID 不撤回）；
//     ARADDR/ARLEN 锁存于请求握手拍，AR 态保持稳定。
//   - RDATA 态 R 通道与 FIFO 入队侧组合直通（rvalid -> fifo_valid，
//     fifo_ready -> rready）；错误 beat 数据照入 FIFO——AR 已发出，
//     必须收完整 burst，错误统一由 done/err 汇报。
//   - 逐握手拍检查 RRESP：SLVERR -> ERR_SLV，DECERR -> ERR_DEC，
//     其他非 OKAY（含 EXOKAY）-> ERR_RRESP；多个错误取第一个锁存值。
//   - RLAST 握手拍校验已完成 beat 数与 ARLEN 一致，提前/超拍均报 ERR_RRESP。
//-----------------------------------------------------------------------------
module axi_rd_ch (
  input  logic        clk,
  input  logic        rst_n,          // 低有效异步复位
  // DMA 引擎请求（valid/ready 握手）
  input  logic        rd_req_valid_i,
  output logic        rd_req_ready_o,
  input  logic [31:0] rd_addr_i,      // 读起始地址（word 对齐）
  input  logic [7:0]  rd_beats_i,     // beat 数 - 1（AXI ARLEN 格式；0=SINGLE）
  // 完成/错误（各 1 拍脉冲，互斥）
  output logic        rd_done_o,
  output logic        rd_err_o,
  output logic [1:0]  rd_errcode_o,   // dma_pkg::errcode_e 值，出错后保持
  // AXI4 读地址通道（ARID 固定 0，不引出端口，注释注明）
  output logic [31:0] m_axi_araddr,
  output logic [7:0]  m_axi_arlen,
  output logic [2:0]  m_axi_arsize,
  output logic [1:0]  m_axi_arburst,
  output logic        m_axi_arvalid,
  input  logic        m_axi_arready,
  // AXI4 读数据通道
  input  logic [31:0] m_axi_rdata,
  input  logic [1:0]  m_axi_rresp,
  input  logic        m_axi_rlast,
  input  logic        m_axi_rvalid,
  output logic        m_axi_rready,
  // FIFO 入队侧（外部为 dma_fifo，DEPTH=16 >= beats+1，不会满）
  output logic        fifo_in_valid_o,
  input  logic        fifo_in_ready_i,
  output logic [31:0] fifo_in_data_o
);

  import dma_pkg::*;

  // ---------------------------------------------------------------------
  // 状态与常量
  // ---------------------------------------------------------------------
  localparam logic [1:0] S_IDLE  = 2'b00;  // 空闲，可接受新请求
  localparam logic [1:0] S_AR    = 2'b01;  // 发 AR，等待握手
  localparam logic [1:0] S_RDATA = 2'b10;  // 收 R beat 至 RLAST

  // dma_pkg 未定义 DECERR，此处按 AXI4 标准补充
  localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

  // ---------------------------------------------------------------------
  // 内部信号
  // ---------------------------------------------------------------------
  logic [1:0]  state_q, state_n;      // FSM 现态 / 次态
  logic [31:0] addr_lat_q;            // 锁存的读起始地址
  logic [7:0]  beats_lat_q;           // 锁存的 ARLEN
  logic [7:0]  beat_cnt_q;            // 已完成握手的 R beat 计数
  logic [1:0]  errcode_q, errcode_n;  // 错误码（保持最后错误值）

  logic req_fire, ar_fire, r_fire;    // 三个握手事件

  // ---------------------------------------------------------------------
  // DMA 请求握手（仅 IDLE 态可接受）
  // ---------------------------------------------------------------------
  assign rd_req_ready_o = (state_q == S_IDLE);
  assign req_fire       = rd_req_valid_i && rd_req_ready_o;

  // ---------------------------------------------------------------------
  // AR 通道（ID 固定 0；SIZE=4 字节、BURST=INCR 为固定配置）
  // ---------------------------------------------------------------------
  assign m_axi_araddr  = addr_lat_q;
  assign m_axi_arlen   = beats_lat_q;
  assign m_axi_arsize  = 3'b010;  // 2^2 = 4 字节
  assign m_axi_arburst = 2'b01;   // INCR
  assign m_axi_arvalid = (state_q == S_AR);  // 拉高后保持至握手，不撤回

  assign ar_fire = m_axi_arvalid && m_axi_arready;

  // ---------------------------------------------------------------------
  // R 通道 <-> FIFO 入队侧组合直通（仅 RDATA 态有效）
  //   RREADY 跟随 FIFO 可入队状态，RVALID 直通 FIFO 写请求，
  //   两拍间无寄存，外部 FIFO 不会满（DEPTH >= beats+1）
  // ---------------------------------------------------------------------
  assign m_axi_rready    = (state_q == S_RDATA) && fifo_in_ready_i;
  assign fifo_in_valid_o = (state_q == S_RDATA) && m_axi_rvalid;
  assign fifo_in_data_o  = m_axi_rdata;

  assign r_fire = m_axi_rvalid && m_axi_rready;

  assign rd_errcode_o = errcode_q;

  // ---------------------------------------------------------------------
  // 次态逻辑（组合）
  // ---------------------------------------------------------------------
  always_comb begin
    state_n = state_q;  // 默认保持
    case (state_q)
      S_IDLE:  if (req_fire)                        state_n = S_AR;
      S_AR:    if (ar_fire)                         state_n = S_RDATA;
      S_RDATA: if (r_fire && m_axi_rlast)           state_n = S_IDLE;
      default:                                      state_n = S_IDLE;
    endcase
  end

  // ---------------------------------------------------------------------
  // 错误码下一值（组合）
  //   请求握手拍清零；RDATA 态逐握手拍采样 RRESP，仅第一个错误被锁存；
  //   RLAST 握手拍校验 beat 计数一致性（提前/超拍均报 ERR_RRESP）
  // ---------------------------------------------------------------------
  always_comb begin
    errcode_n = errcode_q;
    if (req_fire) begin
      errcode_n = ERR_NONE;  // 新传输开始清零
    end else if (state_q == S_RDATA && r_fire) begin
      if (errcode_q == ERR_NONE) begin
        if (m_axi_rresp == AXI_RESP_SLVERR)
          errcode_n = ERR_SLV;
        else if (m_axi_rresp == AXI_RESP_DECERR)
          errcode_n = ERR_DEC;
        else if (m_axi_rresp != AXI_RESP_OKAY)
          errcode_n = ERR_RRESP;  // 其余非 OKAY 响应（含 EXOKAY）
      end
      if (m_axi_rlast && (beat_cnt_q != beats_lat_q) && (errcode_n == ERR_NONE))
        errcode_n = ERR_RRESP;    // burst 长度与 ARLEN 不符
    end
  end

  // ---------------------------------------------------------------------
  // 状态 / 锁存 / 计数 / 错误码寄存器（异步复位，复位清零）
  // ---------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q     <= S_IDLE;
      addr_lat_q  <= '0;
      beats_lat_q <= '0;
      beat_cnt_q  <= '0;
      errcode_q   <= ERR_NONE;
    end else begin
      state_q   <= state_n;
      errcode_q <= errcode_n;
      if (req_fire) begin
        addr_lat_q  <= rd_addr_i;   // 锁存本次传输参数
        beats_lat_q <= rd_beats_i;
        beat_cnt_q  <= '0;
      end else if (r_fire) begin
        beat_cnt_q <= beat_cnt_q + 1'b1;  // 计已完成握手的 beat
      end
    end
  end

  // ---------------------------------------------------------------------
  // 完成/错误脉冲（寄存输出）
  //   RDATA -> IDLE 的转移由 RLAST 握手触发，脉冲出现在握手后下一拍，
  //   与 state 回 IDLE 同拍；errcode_q 同拍已更新为最终错误值
  // ---------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_done_o <= 1'b0;
      rd_err_o  <= 1'b0;
    end else if (state_q == S_RDATA && state_n == S_IDLE) begin
      rd_done_o <= (errcode_n == ERR_NONE);  // 无错
      rd_err_o  <= (errcode_n != ERR_NONE);  // 有错
    end else begin
      rd_done_o <= 1'b0;
      rd_err_o  <= 1'b0;
    end
  end

endmodule
