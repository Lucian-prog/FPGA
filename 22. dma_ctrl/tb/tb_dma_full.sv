`timescale 1ns/1ps

//=============================================================================
// tb_dma_full —— DMA Phase 4 顶层集成自检 TB（例化 dma_top）
//
// 例化链：axi_lite_bfm <-> dma_top(u_dut) <-> axi_mem_slave（源/目的共存储）
// Phase 4 起直接驱动/观测顶层端口，验证封装后全链行为不变。
//
// 用例：
//   U1 SINGLE 端到端：len=1，dst 内存比对
//   U2 满 burst：len=16 / burst=16，单 burst 完成搬运
//   U3 非整切：len=37 / burst=16 -> 16+16+5，AR/AW 各 3 个 burst
//   U4 跨 4KB 边界：src=0xFF8 len=8 -> 首批被边界余量截为 2 beat + 尾批 6
//   U5 双侧反压 + busy 写保护：ar/aw/w 三处反压，传输中 BUSY=1 且写被忽略
//   U6 写侧 SLVERR：AW 命中注入地址 -> ERROR / ERRCODE=ERR_SLV / TE 中断
//   U7 LEN=0：立即完成，无 burst 发出
//   U8 ARVALID 保持：ar_ready_delay=5，校验 ARVALID 到握手不撤回
//   U9 读侧 SLVERR：beat 命中注入地址 -> ERROR / FIFO 残留不影响后续
//        （置于最后：错误 beat 数据照入 FIFO，封装后 TB 无法排空内部 FIFO，
//          通过用例排序保证残留不影响任何后续比对）
//=============================================================================

module tb_dma_full;

  import dma_pkg::*;

  //---------------------------------------------------------------------------
  // 时钟 / 复位
  //---------------------------------------------------------------------------
  logic clk;
  logic rst_n;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  //---------------------------------------------------------------------------
  // AXI4-Lite 总线（BFM <-> dma_top）
  //---------------------------------------------------------------------------
  logic [31:0] axil_awaddr, axil_wdata, axil_araddr, axil_rdata;
  logic [2:0]  axil_awprot;
  logic [3:0]  axil_wstrb;
  logic        axil_awvalid, axil_awready, axil_wvalid, axil_wready, axil_bvalid;
  logic [1:0]  axil_bresp, axil_rresp;
  logic        axil_arvalid, axil_arready, axil_rvalid;

  //---------------------------------------------------------------------------
  // AXI 总线（dma_top <-> mem_slave）
  //---------------------------------------------------------------------------
  logic [31:0] m_axi_araddr, m_axi_rdata;
  logic [7:0]  m_axi_arlen;
  logic [2:0]  m_axi_arsize;
  logic [1:0]  m_axi_arburst, m_axi_rresp;
  logic        m_axi_arvalid, m_axi_arready, m_axi_rvalid, m_axi_rready, m_axi_rlast;

  logic [31:0] m_axi_awaddr, m_axi_wdata;
  logic [7:0]  m_axi_awlen;
  logic [2:0]  m_axi_awsize;
  logic [1:0]  m_axi_awburst, m_axi_bresp;
  logic        m_axi_awvalid, m_axi_awready, m_axi_wvalid, m_axi_wready;
  logic        m_axi_wlast, m_axi_bvalid, m_axi_bready;
  logic [3:0]  m_axi_wstrb;

  logic        irq_tc, irq_te;

  //---------------------------------------------------------------------------
  // SVA 断言检查模块（P5）：内部信号经层次引用自 u_dut 连入
  //---------------------------------------------------------------------------
  dma_sva_chk u_sva (
    .clk         (clk),
    .rst_n       (rst_n),
    .arvalid     (m_axi_arvalid),
    .arready     (m_axi_arready),
    .awvalid     (m_axi_awvalid),
    .awready     (m_axi_awready),
    .wvalid      (m_axi_wvalid),
    .wready      (m_axi_wready),
    .start_pulse (u_dut.start_pulse),
    .busy        (u_dut.sts_busy),
    .tc_event    (u_dut.tc_event),
    .te_event    (u_dut.te_event),
    .xfer_len    (u_dut.cfg_len),
    .fifo_cnt    (u_dut.u_fifo.count)
  );

  //---------------------------------------------------------------------------
  // DUT 与周边模型例化
  //---------------------------------------------------------------------------
  dma_top u_dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_axil_awaddr  (axil_awaddr),
    .s_axil_awprot  (axil_awprot),
    .s_axil_awvalid (axil_awvalid),
    .s_axil_awready (axil_awready),
    .s_axil_wdata   (axil_wdata),
    .s_axil_wstrb   (axil_wstrb),
    .s_axil_wvalid  (axil_wvalid),
    .s_axil_wready  (axil_wready),
    .s_axil_bresp   (axil_bresp),
    .s_axil_bvalid  (axil_bvalid),
    .s_axil_araddr  (axil_araddr),
    .s_axil_arvalid (axil_arvalid),
    .s_axil_arready (axil_arready),
    .s_axil_rdata   (axil_rdata),
    .s_axil_rresp   (axil_rresp),
    .s_axil_rvalid  (axil_rvalid),
    .m_axi_araddr   (m_axi_araddr),
    .m_axi_arlen    (m_axi_arlen),
    .m_axi_arsize   (m_axi_arsize),
    .m_axi_arburst  (m_axi_arburst),
    .m_axi_arvalid  (m_axi_arvalid),
    .m_axi_arready  (m_axi_arready),
    .m_axi_rdata    (m_axi_rdata),
    .m_axi_rresp    (m_axi_rresp),
    .m_axi_rlast    (m_axi_rlast),
    .m_axi_rvalid   (m_axi_rvalid),
    .m_axi_rready   (m_axi_rready),
    .m_axi_awaddr   (m_axi_awaddr),
    .m_axi_awlen    (m_axi_awlen),
    .m_axi_awsize   (m_axi_awsize),
    .m_axi_awburst  (m_axi_awburst),
    .m_axi_awvalid  (m_axi_awvalid),
    .m_axi_awready  (m_axi_awready),
    .m_axi_wdata    (m_axi_wdata),
    .m_axi_wstrb    (m_axi_wstrb),
    .m_axi_wlast    (m_axi_wlast),
    .m_axi_wvalid   (m_axi_wvalid),
    .m_axi_wready   (m_axi_wready),
    .m_axi_bresp    (m_axi_bresp),
    .m_axi_bvalid   (m_axi_bvalid),
    .m_axi_bready   (m_axi_bready),
    .irq_tc_o       (irq_tc),
    .irq_te_o       (irq_te)
  );

  axi_lite_bfm u_bfm (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_axil_awaddr  (axil_awaddr),
    .s_axil_awprot  (axil_awprot),
    .s_axil_awvalid (axil_awvalid),
    .s_axil_awready (axil_awready),
    .s_axil_wdata   (axil_wdata),
    .s_axil_wstrb   (axil_wstrb),
    .s_axil_wvalid  (axil_wvalid),
    .s_axil_wready  (axil_wready),
    .s_axil_bresp   (axil_bresp),
    .s_axil_bvalid  (axil_bvalid),
    .s_axil_araddr  (axil_araddr),
    .s_axil_arvalid (axil_arvalid),
    .s_axil_arready (axil_arready),
    .s_axil_rdata   (axil_rdata),
    .s_axil_rresp   (axil_rresp),
    .s_axil_rvalid  (axil_rvalid)
  );

  axi_mem_slave u_mem (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_axi_araddr   (m_axi_araddr),
    .s_axi_arlen    (m_axi_arlen),
    .s_axi_arsize   (m_axi_arsize),
    .s_axi_arburst  (m_axi_arburst),
    .s_axi_arvalid  (m_axi_arvalid),
    .s_axi_arready  (m_axi_arready),
    .s_axi_rdata    (m_axi_rdata),
    .s_axi_rresp    (m_axi_rresp),
    .s_axi_rlast    (m_axi_rlast),
    .s_axi_rvalid   (m_axi_rvalid),
    .s_axi_rready   (m_axi_rready),
    .s_axi_awaddr   (m_axi_awaddr),
    .s_axi_awlen    (m_axi_awlen),
    .s_axi_awsize   (m_axi_awsize),
    .s_axi_awburst  (m_axi_awburst),
    .s_axi_awvalid  (m_axi_awvalid),
    .s_axi_awready  (m_axi_awready),
    .s_axi_wdata    (m_axi_wdata),
    .s_axi_wstrb    (m_axi_wstrb),
    .s_axi_wlast    (m_axi_wlast),
    .s_axi_wvalid   (m_axi_wvalid),
    .s_axi_wready   (m_axi_wready),
    .s_axi_bresp    (m_axi_bresp),
    .s_axi_bvalid   (m_axi_bvalid),
    .s_axi_bready   (m_axi_bready)
  );

  //---------------------------------------------------------------------------
  // 检查统计与通用任务
  //---------------------------------------------------------------------------
  int pass_cnt = 0;
  int fail_cnt = 0;

  task automatic check(input bit cond, input string msg);
    if (cond) begin
      pass_cnt++;
      $display("[PASS] %s", msg);
    end else begin
      fail_cnt++;
      $display("[FAIL] %s", msg);
    end
  endtask

  // 期望数据数组（预填时同步记录）
  logic [31:0] exp_mem [1024];

  task automatic fill_src(input logic [31:0] src, input int len);
    logic [31:0] d;
    for (int i = 0; i < len; i++) begin
      d = $random;
      u_mem.mem_write(src + i * 4, d);
      exp_mem[i] = d;
    end
  endtask

  task automatic check_dst(input logic [31:0] dst, input int len, input string tag);
    bit ok = 1'b1;
    for (int i = 0; i < len; i++) begin
      if (u_mem.mem[(dst + i * 4) >> 2] !== exp_mem[i]) begin
        ok = 1'b0;
        $display("  mismatch @dst+%0d: mem=%h exp=%h",
                 i, u_mem.mem[(dst + i * 4) >> 2], exp_mem[i]);
      end
    end
    check(ok, {tag, " dst memory diff clean"});
  endtask

  // 等待传输结束：2 拍缓冲 + DONE/ERRCODE 轮询
  task automatic wait_xfer_end(output logic [31:0] status, output bit to_flag);
    int n = 0;
    to_flag = 1'b0;
    repeat (2) @(posedge clk);
    forever begin
      u_bfm.axil_read({26'd0, REG_STATUS}, status);
      if (status[ST_DONE] === 1'b1) break;
      if (status[ST_ERR_LSB +: ST_ERR_W] != ERR_NONE) break;
      if (++n > 500) begin
        to_flag = 1'b1;
        break;
      end
    end
  endtask

  // ARVALID 死锁规避监视：拉高到握手期间不撤回
  task automatic monitor_ar_hold(output int held_cnt, output bit violated);
    while (m_axi_arvalid !== 1'b1) @(posedge clk);
    held_cnt = 0;
    violated = 1'b0;
    forever begin
      @(posedge clk);
      if (m_axi_arready === 1'b1) break;
      if (m_axi_arvalid !== 1'b1) violated = 1'b1;
      held_cnt++;
    end
  endtask

  // 用例清理：清中断、复位注入/反压配置、清事务计数
  task automatic cleanup;
    u_bfm.axil_write({26'd0, REG_ICR}, 32'h3);
    u_mem.ar_ready_delay = 0;
    u_mem.aw_ready_delay = 0;
    u_mem.w_ready_gap    = 0;
    u_mem.err_en         = 1'b0;
    u_mem.wr_err_en      = 1'b0;
    u_mem.ar_xfer_cnt    = 0;
    u_mem.aw_xfer_cnt    = 0;
  endtask

  // 配置并启动一次传输：burst_log2 = 0..4；ie_te 置位 TE 中断使能
  task automatic start_xfer(input logic [31:0] src, dst,
                            input logic [31:0] len, input int burst_log2,
                            input bit ie_te = 1'b0);
    u_bfm.axil_write({26'd0, REG_SRC}, src);
    u_bfm.axil_write({26'd0, REG_DST}, dst);
    u_bfm.axil_write({26'd0, REG_LEN}, len);
    u_bfm.axil_write({26'd0, REG_CTRL},
                     32'h2 | (burst_log2 << 2) | (ie_te << 9));  // START(+IE_TE)
  endtask

  //---------------------------------------------------------------------------
  // 主流程
  //---------------------------------------------------------------------------
  logic [31:0] status;
  bit          to_flag;
  int          held_cnt;
  bit          violated;

  initial begin : main
    rst_n = 1'b0;
    repeat (10) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    //=========================================================================
    $display("--- U1: SINGLE end-to-end ---");
    //=========================================================================
    fill_src(32'h0000_0100, 1);
    start_xfer(32'h0000_0100, 32'h0000_0300, 32'd1, 0);
    wait_xfer_end(status, to_flag);
    check(!to_flag,                              "U1 no timeout");
    check(status[ST_DONE] === 1'b1,              "U1 DONE set");
    check(status[ST_ERR_LSB +: ST_ERR_W] == ERR_NONE, "U1 no error");
    check(u_mem.ar_xfer_cnt == 1,                "U1 1 read burst");
    check(u_mem.aw_xfer_cnt == 1,                "U1 1 write burst");
    check_dst(32'h0000_0300, 1, "U1");
    cleanup();

    //=========================================================================
    $display("--- U2: full burst len=16 ---");
    //=========================================================================
    fill_src(32'h0000_0110, 16);
    start_xfer(32'h0000_0110, 32'h0000_0310, 32'd16, 4);   // burst=16
    wait_xfer_end(status, to_flag);
    check(!to_flag,                              "U2 no timeout");
    check(status[ST_DONE] === 1'b1,              "U2 DONE set");
    check(u_mem.ar_xfer_cnt == 1,                "U2 1 read burst (16 beats)");
    check(u_mem.aw_xfer_cnt == 1,                "U2 1 write burst");
    check_dst(32'h0000_0310, 16, "U2");
    cleanup();

    //=========================================================================
    $display("--- U3: non-power-of-2 len=37 burst=16 -> 16+16+5 ---");
    //=========================================================================
    fill_src(32'h0000_0120, 37);
    start_xfer(32'h0000_0120, 32'h0000_0320, 32'd37, 4);
    wait_xfer_end(status, to_flag);
    check(!to_flag,                              "U3 no timeout");
    check(status[ST_DONE] === 1'b1,              "U3 DONE set");
    check(u_mem.ar_xfer_cnt == 3,                "U3 3 read bursts (16+16+5)");
    check(u_mem.aw_xfer_cnt == 3,                "U3 3 write bursts");
    check_dst(32'h0000_0320, 37, "U3");
    cleanup();

    //=========================================================================
    $display("--- U4: 4KB boundary src=0xFF8 len=8 -> 2+6 ---");
    //=========================================================================
    fill_src(32'h0000_0FF8, 8);      // beat 地址回绕：0xFF8,0xFFC,0x000,0x004...
    start_xfer(32'h0000_0FF8, 32'h0000_0240, 32'd8, 4);
    wait_xfer_end(status, to_flag);
    check(!to_flag,                              "U4 no timeout");
    check(status[ST_DONE] === 1'b1,              "U4 DONE set");
    check(u_mem.ar_xfer_cnt == 2,                "U4 2 read bursts (2+6 split)");
    check(u_mem.aw_xfer_cnt == 2,                "U4 2 write bursts");
    check_dst(32'h0000_0240, 8, "U4");
    cleanup();

    //=========================================================================
    $display("--- U5: dual-side backpressure + busy write protection ---");
    //=========================================================================
    fill_src(32'h0000_0130, 20);
    u_mem.ar_ready_delay = 4;
    u_mem.aw_ready_delay = 4;
    u_mem.w_ready_gap    = 3;
    start_xfer(32'h0000_0130, 32'h0000_0330, 32'd20, 3);   // burst=8 -> 8+8+4
    // 传输中（反压拉长窗口）：BUSY=1，写 SRC 被静默忽略
    repeat (3) @(posedge clk);
    u_bfm.axil_read({26'd0, REG_STATUS}, status);
    check(status[ST_BUSY] === 1'b1,              "U5 BUSY high during xfer");
    u_bfm.axil_write({26'd0, REG_SRC}, 32'hDEAD_BEEF);
    check(u_bfm.wr_resp == AXI_RESP_OKAY,        "U5 busy write resp OKAY");
    wait_xfer_end(status, to_flag);
    check(!to_flag,                              "U5 no timeout");
    check(status[ST_DONE] === 1'b1,              "U5 DONE set");
    check(u_mem.ar_xfer_cnt == 3,                "U5 3 read bursts under pressure");
    u_bfm.axil_read({26'd0, REG_SRC}, status);
    check(status === 32'h0000_0130,              "U5 SRC unchanged (write ignored)");
    check_dst(32'h0000_0330, 20, "U5");
    cleanup();

    //=========================================================================
    $display("--- U6: write-side SLVERR -> ERROR ---");
    //=========================================================================
    fill_src(32'h0000_0140, 4);
    u_mem.wr_err_addr = 32'h0000_0340;
    u_mem.wr_err_en   = 1'b1;
    start_xfer(32'h0000_0140, 32'h0000_0340, 32'd4, 0, 1'b1);  // IE_TE=1
    wait_xfer_end(status, to_flag);
    check(!to_flag,                              "U6 no timeout");
    check(status[ST_DONE] === 1'b0,              "U6 DONE not set");
    check(status[ST_ERR_LSB +: ST_ERR_W] == ERR_SLV, "U6 ERRCODE=ERR_SLV");
    check(irq_te === 1'b1,                       "U6 irq_te high");
    cleanup();

    //=========================================================================
    $display("--- U7: LEN=0 immediate DONE ---");
    //=========================================================================
    start_xfer(32'h0000_0150, 32'h0000_0350, 32'd0, 0);
    wait_xfer_end(status, to_flag);
    check(!to_flag,                              "U7 no timeout");
    check(status[ST_DONE] === 1'b1,              "U7 DONE set");
    check(u_mem.ar_xfer_cnt == 0,                "U7 no read burst");
    check(u_mem.aw_xfer_cnt == 0,                "U7 no write burst");
    cleanup();

    //=========================================================================
    $display("--- U8: ARVALID held until ARREADY ---");
    //=========================================================================
    fill_src(32'h0000_0170, 1);
    u_mem.ar_ready_delay = 5;
    start_xfer(32'h0000_0170, 32'h0000_0370, 32'd1, 0);
    monitor_ar_hold(held_cnt, violated);
    check(!violated,                             "U8 ARVALID never withdrawn");
    check(held_cnt >= 5,                         "U8 ARVALID held >=5 cycles");
    wait_xfer_end(status, to_flag);
    check(status[ST_DONE] === 1'b1,              "U8 still completes");
    check_dst(32'h0000_0370, 1, "U8");
    cleanup();

    //=========================================================================
    $display("--- U9: read-side SLVERR -> ERROR（置于最后：FIFO 残留不扩散）---");
    //=========================================================================
    fill_src(32'h0000_0160, 2);
    u_mem.err_addr = 32'h0000_0160;              // 首 beat 即注入读侧 SLVERR
    u_mem.err_en   = 1'b1;
    start_xfer(32'h0000_0160, 32'h0000_0360, 32'd2, 0, 1'b1);  // IE_TE=1
    wait_xfer_end(status, to_flag);
    check(!to_flag,                              "U9 no timeout");
    check(status[ST_BUSY] === 1'b0,              "U9 BUSY low after error");
    check(status[ST_DONE] === 1'b0,              "U9 DONE not set");
    check(status[ST_ERR_LSB +: ST_ERR_W] == ERR_SLV, "U9 ERRCODE=ERR_SLV");
    check(irq_te === 1'b1,                       "U9 irq_te high after TE");
    cleanup();

    //=========================================================================
    $display("=================================================");
    u_sva.print_summary;                          // 属性检查汇总（P5）
    if (fail_cnt == 0 && u_sva.fail_cnt == 0) begin
      $display(" Test Summary : %0d/%0d checks passed", pass_cnt, pass_cnt + fail_cnt);
      $display("[FINISH] PASS");
    end else begin
      $display(" Test Summary : %0d/%0d checks passed", pass_cnt, pass_cnt + fail_cnt);
      $display("[FINISH] FAIL");
    end
    $display("=================================================");
    $finish;
  end

  //---------------------------------------------------------------------------
  // 看门狗
  //---------------------------------------------------------------------------
  initial begin
    #500_000;
    $display("[FAIL] watchdog timeout");
    $display("[FINISH] FAIL");
    $finish;
  end

endmodule
