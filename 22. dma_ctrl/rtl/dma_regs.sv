//=============================================================================
// dma_regs.sv —— DMA 控制器配置寄存器组（AXI4-Lite slave）
//
// 功能：
//   1. 简化 AXI4-Lite 从机：awready/wready/arready 常高；aw、w 全部握手完成
//      后下一拍产生单拍 bvalid（无 bready 依赖）；arvalid 拍接受读地址，
//      下一拍单拍 rvalid + rdata/rresp（rvalid 撤回后 rdata 保持最后值）。
//   2. 寄存器组（偏移/位域引用 dma_pkg，word 对齐）：
//        0x00 REG_SRC    RW  源起始地址
//        0x04 REG_DST    RW  目的起始地址
//        0x08 REG_LEN    RW  传输长度
//        0x0C REG_CTRL   RW  EN/START/BURST/IE_TC/IE_TE，START 写 1 触发后自清
//        0x10 REG_STATUS RO  读值 = busy_i/done_i/errcode_i 实时拼装
//        0x14 REG_ICR    WO  写 1 清中断标志（读回 0）
//   3. 中断：tc_event_i/te_event_i 脉冲置标志，ICR 清除，
//      irq_tc_o = tc_flag_q & IE_TC，irq_te_o = te_flag_q & IE_TE。
//
// 设计决策（规格允许范围内的选择，均已注释）：
//   - busy_i=1 期间所有写（含 ICR）静默忽略：握手照常完成、bresp=OKAY、
//     寄存器不更新。软件无需感知保护窗口，简化驱动编写。
//   - 写 REG_STATUS（RO）地址命中、返回 OKAY、不更新任何寄存器。
//   - ICR 位域 dma_pkg 未定义，本模块约定：ICR[0]=清 TC，ICR[1]=清 TE。
//   - 事件置位与 ICR 清除同拍冲突时，置位优先（后赋值覆盖），不丢新事件。
//=============================================================================

module dma_regs (
  input  logic        clk,
  input  logic        rst_n,          // 低有效异步复位
  // AXI4-Lite slave（简化五通道：B/R 响应无 ready，bvalid/rvalid 为单拍脉冲）
  input  logic [31:0] s_axil_awaddr,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [2:0]  s_axil_awprot,  // 未使用，保留端口（不检查保护属性）
  /* verilator lint_on UNUSEDSIGNAL */
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
  // 配置输出（到 DMA 引擎）
  output logic [31:0] src_o,
  output logic [31:0] dst_o,
  output logic [31:0] len_o,
  output logic        ctrl_en_o,
  output logic [2:0]  ctrl_burst_o,   // CTRL.BURST 字段 [4:2]
  output logic        ctrl_ie_tc_o,   // CTRL.IE_TC
  output logic        ctrl_ie_te_o,   // CTRL.IE_TE
  // 状态输入（来自 DMA 引擎，直通到 STATUS 寄存器读值）
  input  logic        busy_i,
  input  logic        done_i,
  input  logic [1:0]  errcode_i,      // dma_pkg::errcode_e 值
  // 事件输入（1 拍脉冲，置位内部中断标志）
  input  logic        tc_event_i,     // 传输完成事件 → 置 TC 标志
  input  logic        te_event_i,     // 传输错误事件 → 置 TE 标志
  // 事件/中断输出
  output logic        start_pulse_o,  // CTRL.START 写 1 后输出 1 拍脉冲
  output logic        irq_tc_o,       // 电平：TC 标志 & IE_TC
  output logic        irq_te_o        // 电平：TE 标志 & IE_TE
);

  import dma_pkg::*;

  //===========================================================================
  // 内部信号
  //===========================================================================
  logic [31:0] src_q, dst_q, len_q;   // 配置寄存器
  logic [31:0] ctrl_q;                // CTRL（START 位兼作 start 状态位，写入后自清）
  logic        tc_flag_q, te_flag_q;  // 中断标志（事件置位 / ICR 清除）

  // 写通道握手收集
  logic        aw_done_q, w_done_q;   // aw/w 已完成握手（valid 当拍即握手，ready 常高）
  logic        bvalid_q;              // 单拍写响应脉冲
  logic [31:0] awaddr_q;              // 已锁存的写地址
  logic [31:0] wdata_q;               // 已锁存的写数据
  logic [3:0]  wstrb_q;               // 已锁存的字节使能

  // 读通道
  logic        rvalid_q;              // 单拍读响应脉冲
  logic [31:0] rdata_q;               // 读数据（rvalid 撤回后保持最后值）
  logic [1:0]  rresp_q;

  logic        start_pulse_q;         // START 触发脉冲寄存器

  // 组合中间信号
  logic        wr_go;                 // aw+w 收集完成，下一拍出 bvalid
  logic        wr_commit;             // bvalid 拍 = 寄存器写入提交拍
  logic        wr_hit;                // 写地址命中合法寄存器空间
  logic [5:0]  wr_byte_addr;          // 锁存地址的 word 对齐字节偏移（6 位，与 REG_* 比较）
  logic [5:0]  rd_byte_addr;          // 读地址的 word 对齐字节偏移
  logic [31:0] rd_data_d;            // 读数据组合拼装
  logic [1:0]  rd_resp_d;
  logic [31:0] ctrl_wr_val;           // CTRL 写入值（wstrb 合并后）

  //===========================================================================
  // wstrb 字节使能合并：strb[i]=1 写入对应字节，否则保持旧值（标准 AXI 行为）
  //===========================================================================
  function automatic logic [31:0] byte_merge (
    input logic [31:0] old_val,
    input logic [31:0] new_val,
    input logic [3:0]  strb
  );
    for (int b = 0; b < 4; b++) begin
      byte_merge[b*8 +: 8] = strb[b] ? new_val[b*8 +: 8] : old_val[b*8 +: 8];
    end
  endfunction

  //===========================================================================
  // 写地址/写数据通道：ready 常高，valid 当拍即完成握手
  // aw 与 w 可不同拍到达，各自锁存并置 done 标志；两者齐后的下一拍产生
  // 单拍 bvalid。bvalid 拍压住 wr_go，保证连续事务的 bvalid 之间至少隔 1 拍。
  //===========================================================================
  assign s_axil_awready = 1'b1;
  assign s_axil_wready  = 1'b1;

  assign wr_go = (aw_done_q | s_axil_awvalid) &
                 (w_done_q  | s_axil_wvalid ) & ~bvalid_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_done_q <= 1'b0;
      w_done_q  <= 1'b0;
      awaddr_q  <= '0;
      wdata_q   <= '0;
      wstrb_q   <= '0;
      bvalid_q  <= 1'b0;
    end else begin
      bvalid_q <= 1'b0;  // 默认单拍撤销
      // done 未置位时采样，防止 awaddr/wdata 被后续 valid 重复覆盖
      if (s_axil_awvalid && !aw_done_q) awaddr_q <= s_axil_awaddr;
      if (s_axil_wvalid  && !w_done_q ) begin
        wdata_q <= s_axil_wdata;
        wstrb_q <= s_axil_wstrb;
      end
      if (wr_go) begin
        aw_done_q <= 1'b0;   // 事务收集完成，回收标志
        w_done_q  <= 1'b0;
        bvalid_q  <= 1'b1;   // 下一拍输出单拍 bvalid
      end else begin
        if (s_axil_awvalid) aw_done_q <= 1'b1;
        if (s_axil_wvalid ) w_done_q  <= 1'b1;
      end
    end
  end

  //===========================================================================
  // 写地址解码与响应（基于已锁存 awaddr_q，bvalid 拍输出有效）
  // 取 [7:2] 拼 2'b00 还原为 word 对齐字节偏移，丢弃 [1:0] 字节位
  //===========================================================================
  assign wr_byte_addr = {awaddr_q[7:2], 2'b00};

  always_comb begin
    unique case (wr_byte_addr)
      REG_SRC, REG_DST, REG_LEN, REG_CTRL, REG_STATUS, REG_ICR: wr_hit = 1'b1;
      default: wr_hit = 1'b0;   // 超出 0x00~0x14 → 非法偏移
    endcase
  end

  // 非法地址 SLVERR；合法地址（含 busy 期间被忽略的写）一律 OKAY
  assign s_axil_bresp  = wr_hit ? AXI_RESP_OKAY : AXI_RESP_SLVERR;
  assign s_axil_bvalid = bvalid_q;
  assign wr_commit     = bvalid_q;  // bvalid 拍执行寄存器写入提交

  //===========================================================================
  // 配置寄存器写入（bvalid 拍提交，此时 awaddr/wdata/wstrb 均已锁存稳定）
  //
  // busy_i=1 期间所有写静默忽略（设计决策）：握手照常完成、bresp=OKAY、
  // 寄存器不更新，软件无需判断保护窗口。
  //
  // CTRL.START 自清时序（写入拍记为 T）：
  //   T 拍   ：ctrl_q 整体写入（START=1）、start_pulse_q 置位
  //   T+1 拍 ：start_pulse_o=1（脉冲当拍，读 CTRL 可见 START=1）
  //   T+2 拍 ：ctrl_q[START] 自清回 0，脉冲撤销 —— 不晚于写入后第 2 拍
  //===========================================================================
  assign ctrl_wr_val = byte_merge(ctrl_q, wdata_q, wstrb_q);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      src_q  <= '0;
      dst_q  <= '0;
      len_q  <= '0;
      ctrl_q <= '0;
    end else if (wr_commit && wr_hit && !busy_i) begin
      unique case (wr_byte_addr)
        REG_SRC:   src_q  <= byte_merge(src_q,  wdata_q, wstrb_q);
        REG_DST:   dst_q  <= byte_merge(dst_q,  wdata_q, wstrb_q);
        REG_LEN:   len_q  <= byte_merge(len_q,  wdata_q, wstrb_q);
        REG_CTRL:  ctrl_q <= ctrl_wr_val;   // START 位原样写入，随后由自清分支回 0
        default: ;                          // STATUS(RO)/ICR(标志块处理)/非法：不更新
      endcase
    end else if (ctrl_q[CTRL_START]) begin
      ctrl_q[CTRL_START] <= 1'b0;           // 1 拍后自清（busy 保护不影响自清）
    end
  end

  // START 触发脉冲：写 CTRL 且 START 位=1（且未被 busy 保护拦截）→ 恰好 1 拍
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_pulse_q <= 1'b0;
    end else if (wr_commit && wr_hit && !busy_i &&
                 (wr_byte_addr == REG_CTRL) && ctrl_wr_val[CTRL_START]) begin
      start_pulse_q <= 1'b1;
    end else begin
      start_pulse_q <= 1'b0;
    end
  end
  assign start_pulse_o = start_pulse_q;

  //===========================================================================
  // 中断标志：事件脉冲置位，ICR 写 1 清除（ICR[0]=清 TC，ICR[1]=清 TE）
  // 同拍"清除+置位"冲突时置位优先（后赋值覆盖），保证新事件不丢失。
  // busy 期间 ICR 同样被保护，写清除被静默忽略。
  //===========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tc_flag_q <= 1'b0;
      te_flag_q <= 1'b0;
    end else begin
      if (wr_commit && wr_hit && !busy_i && (wr_byte_addr == REG_ICR)) begin
        if (wdata_q[0]) tc_flag_q <= 1'b0;
        if (wdata_q[1]) te_flag_q <= 1'b0;
      end
      if (tc_event_i) tc_flag_q <= 1'b1;
      if (te_event_i) te_flag_q <= 1'b1;
    end
  end

  //===========================================================================
  // 读通道：arready 常高，arvalid 拍组合解码并锁存，下一拍单拍 rvalid
  // rdata/rresp 为寄存器输出，rvalid 撤回后保持最后值
  //===========================================================================
  assign s_axil_arready = 1'b1;
  assign rd_byte_addr   = {s_axil_araddr[7:2], 2'b00};

  always_comb begin
    rd_data_d  = 32'h0;
    rd_resp_d  = AXI_RESP_SLVERR;
    unique case (rd_byte_addr)
      REG_SRC:  begin rd_data_d = src_q;  rd_resp_d = AXI_RESP_OKAY; end
      REG_DST:  begin rd_data_d = dst_q;  rd_resp_d = AXI_RESP_OKAY; end
      REG_LEN:  begin rd_data_d = len_q;  rd_resp_d = AXI_RESP_OKAY; end
      REG_CTRL: begin rd_data_d = ctrl_q; rd_resp_d = AXI_RESP_OKAY; end
      REG_STATUS: begin
        rd_data_d                  = 32'h0;                       // 其余位读 0
        rd_data_d[ST_BUSY]         = busy_i;
        rd_data_d[ST_DONE]         = done_i;
        rd_data_d[ST_ERR_LSB +: ST_ERR_W] = errcode_i;
        rd_resp_d = AXI_RESP_OKAY;
      end
      REG_ICR:  begin rd_data_d = 32'h0;  rd_resp_d = AXI_RESP_OKAY; end  // WO 读回 0
      default:  begin rd_data_d = 32'h0;  rd_resp_d = AXI_RESP_SLVERR; end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rvalid_q <= 1'b0;
      rdata_q  <= '0;
      rresp_q  <= AXI_RESP_OKAY;
    end else begin
      rvalid_q <= 1'b0;  // 默认单拍撤销
      if (s_axil_arvalid) begin
        rvalid_q <= 1'b1;
        rdata_q  <= rd_data_d;
        rresp_q  <= rd_resp_d;
      end
    end
  end

  assign s_axil_rvalid = rvalid_q;
  assign s_axil_rdata  = rdata_q;
  assign s_axil_rresp  = rresp_q;

  //===========================================================================
  // 配置输出直通与中断门控
  //===========================================================================
  assign src_o        = src_q;
  assign dst_o        = dst_q;
  assign len_o        = len_q;
  assign ctrl_en_o    = ctrl_q[CTRL_EN];
  assign ctrl_burst_o = ctrl_q[CTRL_BURST_LSB +: CTRL_BURST_W];
  assign ctrl_ie_tc_o = ctrl_q[CTRL_IE_TC];
  assign ctrl_ie_te_o = ctrl_q[CTRL_IE_TE];

  assign irq_tc_o = tc_flag_q & ctrl_ie_tc_o;
  assign irq_te_o = te_flag_q & ctrl_ie_te_o;

endmodule
