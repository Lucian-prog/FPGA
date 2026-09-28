//=============================================================================
// dma_ctrl.sv —— DMA 控制器主 FSM（Phase 3 完整版：读写通路 + LEN 循环）
//
// 功能：
//   1. 三段式主状态机（计划 §8 完整 7 态）：
//        IDLE -> RD_REQ -> RD_DATA -> WR_REQ -> WR_DATA -+
//          ^                                              |
//          +---- remain>0 回 RD_REQ <---------------------+
//          +---- remain==0 进 DONE
//        错误（rd_err/wr_err）-> ERROR
//   2. burst 切分：beats_m1 = min(剩余 word 数, 2^BURST, 4KB 边界余量) - 1，
//      读侧每 burst 完成后 remain 递减、读游标前移；写侧复用同批 beat 数，
//      写游标前移；remain==0 且写完成后进 DONE。
//   3. 地址游标：rd_addr = SRC + rd_off*4；wr_addr = DST + wr_off*4。
//   4. busy 从 START 接受次拍覆盖到 DONE/ERROR 次拍；done/errcode 锁存到
//      下一次 START 接受拍清 0（计划 §7）。
//   5. tc_event/te_event 为 1 拍脉冲（DONE/ERROR 态当拍）。
//
// 时序契约（与两个通道的握手）：
//   - RD_REQ 拍锁存本批 cur_m1_q = rd_beats_o（组合计算的 ARLEN），
//     通道握手即转 RD_DATA；
//   - rd_done 拍：remain_q -= cur_beats、rd_off_q += cur_beats，转 WR_REQ；
//   - WR_REQ：wr_beats_o = cur_m1_q（读多少写多少），握手转 WR_DATA；
//   - wr_done 拍：wr_off_q += cur_beats，remain>0 回 RD_REQ 否则 DONE。
//=============================================================================

module dma_ctrl (
  input  logic        clk,
  input  logic        rst_n,          // 低有效异步复位
  // 配置/触发（来自 dma_regs）
  input  logic        start_pulse_i,  // CTRL.START 写 1 触发，1 拍脉冲
  input  logic [31:0] src_i,
  input  logic [31:0] dst_i,
  input  logic [31:0] len_i,          // 总传输 word 数
  input  logic [2:0]  burst_i,        // log2(beats)：0=SINGLE ... 4=16
  // 读通道请求（到 axi_rd_ch，valid/ready 握手）
  output logic        rd_req_valid_o,
  input  logic        rd_req_ready_i,
  output logic [31:0] rd_addr_o,
  output logic [7:0]  rd_beats_o,     // beat 数 - 1（ARLEN 格式）
  // 读通道完成/错误（来自 axi_rd_ch）
  input  logic        rd_done_i,      // 1 拍脉冲
  input  logic        rd_err_i,       // 1 拍脉冲
  input  logic [1:0]  rd_errcode_i,
  // 写通道请求（到 axi_wr_ch，valid/ready 握手）
  output logic        wr_req_valid_o,
  input  logic        wr_req_ready_i,
  output logic [31:0] wr_addr_o,
  output logic [7:0]  wr_beats_o,     // beat 数 - 1（AWLEN 格式）
  // 写通道完成/错误（来自 axi_wr_ch）
  input  logic        wr_done_i,      // 1 拍脉冲
  input  logic        wr_err_i,       // 1 拍脉冲
  input  logic [1:0]  wr_errcode_i,
  // 状态/事件（到 dma_regs）
  output logic        busy_o,
  output logic        done_o,         // DONE 态置 1，保持到下一次 start 清 0
  output logic [1:0]  errcode_o,      // ERROR 态锁存，保持到下一次 start 清 0
  output logic        tc_event_o,     // 1 拍脉冲，DONE 态发一次
  output logic        te_event_o      // 1 拍脉冲，ERROR 态发一次
);

  import dma_pkg::*;

  //===========================================================================
  // 状态编码（计划 §8）
  //===========================================================================
  localparam logic [2:0] ST_IDLE    = 3'b000;
  localparam logic [2:0] ST_RD_REQ  = 3'b001;
  localparam logic [2:0] ST_RD_DATA = 3'b010;
  localparam logic [2:0] ST_WR_REQ  = 3'b011;
  localparam logic [2:0] ST_WR_DATA = 3'b100;
  localparam logic [2:0] ST_DONE    = 3'b101;
  localparam logic [2:0] ST_ERROR   = 3'b110;

  //===========================================================================
  // 内部信号
  //===========================================================================
  logic [2:0]  state_q, state_n;

  logic [31:0] src_q;               // 锁存源/目的基址
  logic [31:0] dst_q;
  logic [31:0] remain_q;            // 剩余 word 数（每读 burst 完成递减）
  logic [31:0] rd_off_q;            // 已读累计 beat 数（读地址游标）
  logic [31:0] wr_off_q;            // 已写累计 beat 数（写地址游标）
  logic [7:0]  cur_m1_q;            // 本批 beat 数 - 1（RD_REQ 拍锁存）

  logic        busy_q;
  logic        done_q;
  logic [1:0]  err_lat_q;

  logic        start_accept;
  logic [7:0]  rd_beats_m1;         // 组合计算的本批 ARLEN
  logic [31:0] cur_beats;           // 本批 beat 数 = cur_m1_q + 1（时序块用）

  assign start_accept = start_pulse_i && (state_q == ST_IDLE);

  //===========================================================================
  // burst 长度计算（读侧专用）：
  //   beats_m1 = min(remain, 2^burst, 4KB 边界余量) - 1
  //===========================================================================
  function automatic logic [7:0] calc_beats_m1 (
    input logic [31:0] addr,
    input logic [31:0] remain,
    input logic [2:0]  burst
  );
    logic [31:0] burst_words;   // 2^burst
    logic [31:0] room_words;    // 4KB 边界余量 word 数
    logic [31:0] beats_min;
    begin
      burst_words = 32'd1 << burst;
      room_words  = (32'd4096 - {20'd0, addr[11:0]}) >> 2;
      beats_min   = (remain < burst_words) ? remain : burst_words;
      if (room_words < beats_min) begin
        beats_min = room_words;  // 跨 4KB 边界截断为短 burst
      end
      calc_beats_m1 = beats_min[7:0] - 8'd1;  // ARLEN 格式 = beat 数 - 1
    end
  endfunction

  //===========================================================================
  // 第一段：状态寄存器（异步复位回 IDLE）
  //===========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= ST_IDLE;
    end else begin
      state_q <= state_n;
    end
  end

  //===========================================================================
  // 第二段：次态组合逻辑
  //===========================================================================
  always_comb begin
    state_n = state_q;  // 默认保持
    unique case (state_q)
      ST_IDLE: begin
        if (start_pulse_i) begin
          if (len_i == 32'd0) begin
            state_n = ST_DONE;     // 0 长度：无搬运立即完成
          end else begin
            state_n = ST_RD_REQ;
          end
        end
      end

      ST_RD_REQ: begin
        if (rd_req_ready_i) begin
          state_n = ST_RD_DATA;    // 握手即转（cur_m1_q 时序块锁存）
        end
      end

      ST_RD_DATA: begin
        if (rd_err_i) begin
          state_n = ST_ERROR;      // 错误优先
        end else if (rd_done_i) begin
          state_n = ST_WR_REQ;     // 本批读完，转写
        end
      end

      ST_WR_REQ: begin
        if (wr_req_ready_i) begin
          state_n = ST_WR_DATA;
        end
      end

      ST_WR_DATA: begin
        if (wr_err_i) begin
          state_n = ST_ERROR;
        end else if (wr_done_i) begin
          // 本批写完：还有剩余回读下一批，否则全部完成
          state_n = (remain_q != 32'd0) ? ST_RD_REQ : ST_DONE;
        end
      end

      ST_DONE: begin
        state_n = ST_IDLE;
      end

      ST_ERROR: begin
        state_n = ST_IDLE;
      end

      default: begin
        state_n = ST_IDLE;         // 非法编码安全回落
      end
    endcase
  end

  //===========================================================================
  // 第三段：输出译码（组合）
  //===========================================================================
  assign rd_beats_m1   = calc_beats_m1(src_q + {rd_off_q[29:0], 2'b00}, remain_q, burst_i);

  assign rd_req_valid_o = (state_q == ST_RD_REQ);
  assign rd_addr_o      = src_q + {rd_off_q[29:0], 2'b00};   // src + rd_off*4
  assign rd_beats_o     = rd_beats_m1;

  assign wr_req_valid_o = (state_q == ST_WR_REQ);
  assign wr_addr_o      = dst_q + {wr_off_q[29:0], 2'b00};   // dst + wr_off*4
  assign wr_beats_o     = cur_m1_q;   // 读多少写多少（同批 beat 数）

  assign busy_o     = busy_q;
  assign done_o     = done_q;
  assign errcode_o  = err_lat_q;
  assign tc_event_o = (state_q == ST_DONE);
  assign te_event_o = (state_q == ST_ERROR);

  //===========================================================================
  // 参数锁存与游标/剩余计数（时序）
  //===========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      src_q    <= '0;
      dst_q    <= '0;
      remain_q <= '0;
      rd_off_q <= '0;
      wr_off_q <= '0;
      cur_m1_q <= '0;
    end else if (start_accept) begin
      src_q    <= src_i;
      dst_q    <= dst_i;
      remain_q <= len_i;
      rd_off_q <= '0;
      wr_off_q <= '0;
      cur_m1_q <= '0;
    end else begin
      // RD_REQ 握手拍：锁存本批 ARLEN（rd_req_valid_o=1 且 ready=1）
      if (rd_req_valid_o && rd_req_ready_i) begin
        cur_m1_q <= rd_beats_m1;
      end
      // rd_done 拍：本批读完成，读游标前移、剩余递减
      if (rd_done_i) begin
        rd_off_q <= rd_off_q + cur_beats;
        remain_q <= remain_q - cur_beats;
      end
      // wr_done 拍：本批写完成，写游标前移
      if (wr_done_i) begin
        wr_off_q <= wr_off_q + cur_beats;
      end
    end
  end

  assign cur_beats = {24'd0, cur_m1_q} + 32'd1;  // 本批 beat 数

  //===========================================================================
  // 标志寄存器（时序）：busy / done / errcode
  //===========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy_q    <= 1'b0;
      done_q    <= 1'b0;
      err_lat_q <= ERR_NONE;
    end else begin
      busy_q <= (state_n != ST_IDLE);
      if (start_accept) begin
        done_q    <= 1'b0;
        err_lat_q <= ERR_NONE;
      end else begin
        if (state_q == ST_DONE) begin
          done_q <= 1'b1;
        end
        if (rd_err_i) begin
          err_lat_q <= rd_errcode_i;   // 读侧错误锁存
        end
        if (wr_err_i) begin
          err_lat_q <= wr_errcode_i;   // 写侧错误锁存（后到覆盖）
        end
      end
    end
  end

endmodule
