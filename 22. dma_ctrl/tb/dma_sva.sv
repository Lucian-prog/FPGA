`timescale 1ns/1ps

//=============================================================================
// dma_sva.sv —— DMA 顶层属性检查模块（Phase 5，程序化 checker 实现）
//
// 例化方式：tb_dma_full 中例化，内部信号（start_pulse/busy/event/len/
// fifo count）经层次引用自 u_dut 连入；总线信号用 TB 级 wire。
//
// 实现说明（重要）：
//   目标属性即计划 §11 的 SVA 清单，但 iverilog 对并发断言语法支持
//   不完整（命名 assert property / disable iff / action block 均不可用），
//   故以"程序化 checker"实现：每条属性 = 时序监视器 + 违例计数 +
//   [SVA-FAIL] 打印。属性语义与标准 SVA 一一对应，在 VCS/Verdi 等
//   商用仿真器下可平替为 assert property 形式（注释中给出对照）。
//
// 属性清单（8 条）：
//   c_arvalid_hold / c_awvalid_hold / c_wvalid_hold
//       AXI 死锁规避：VALID 一经拉高，READY 到来前不撤回
//       （SVA: (v && !r) |=> v）
//   c_start_pulse_1cyc
//       START 触发脉冲恰为单拍（SVA: pulse |=> !pulse）
//   c_busy_no_start
//       BUSY 期间不产生新 START（SVA: busy |-> !pulse）
//   c_tc_count_match
//       完成事件蕴含已写 beat 总数 == 编程 LEN（影子计数支撑）
//       （SVA: tc_event |-> wbeat_cnt == xfer_len）
//   c_te_stop
//       错误事件次拍三通道全部静默（SVA: te |=> !(arv||awv||wv)）
//   c_wvalid_notempty
//       WVALID 有效时 FIFO 必非空（SVA: wv |-> cnt != 0）
//=============================================================================

module dma_sva_chk (
  input  logic        clk,
  input  logic        rst_n,
  // AXI 三通道握手观测（读地址/写地址/写数据）
  input  logic        arvalid, arready,
  input  logic        awvalid, awready,
  input  logic        wvalid,  wready,
  // DMA 内部观测点
  input  logic        start_pulse,   // START 触发脉冲
  input  logic        busy,          // 传输进行中
  input  logic        tc_event,      // 传输完成事件（1 拍）
  input  logic        te_event,      // 传输错误事件（1 拍）
  input  logic [31:0] xfer_len,      // 编程传输长度（cfg_len）
  input  logic [4:0]  fifo_cnt       // FIFO 水位
);

  int fail_cnt = 0;

  //---------------------------------------------------------------------------
  // 影子计数器：累计写通道已完成握手的 beat 数（START 拍清零）
  //---------------------------------------------------------------------------
  logic [31:0] wbeat_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wbeat_cnt <= '0;
    end else if (start_pulse) begin
      wbeat_cnt <= '0;
    end else if (wvalid && wready) begin
      wbeat_cnt <= wbeat_cnt + 1'b1;
    end
  end

  //---------------------------------------------------------------------------
  // 一拍历史寄存（时序类属性用）
  //---------------------------------------------------------------------------
  logic arv_q, arr_q;        // 上拍 AR valid/ready
  logic awv_q, awr_q;        // 上拍 AW valid/ready
  logic wv_q,  wr_q;         // 上拍 W  valid/ready
  logic pulse_q;             // 上拍 start_pulse
  logic te_q;                // 上拍 te_event

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arv_q <= 1'b0;  arr_q <= 1'b0;
      awv_q <= 1'b0;  awr_q <= 1'b0;
      wv_q  <= 1'b0;  wr_q  <= 1'b0;
      pulse_q <= 1'b0;
      te_q  <= 1'b0;
    end else begin
      // ---- c_arvalid_hold：上拍 valid&&!ready，本拍 valid 不得撤回 ----
      if (arv_q && !arr_q && !arvalid) begin
        fail_cnt++;
        $display("[SVA-FAIL] c_arvalid_hold   t=%0t", $time);
      end
      // ---- c_awvalid_hold ----
      if (awv_q && !awr_q && !awvalid) begin
        fail_cnt++;
        $display("[SVA-FAIL] c_awvalid_hold   t=%0t", $time);
      end
      // ---- c_wvalid_hold ----
      if (wv_q && !wr_q && !wvalid) begin
        fail_cnt++;
        $display("[SVA-FAIL] c_wvalid_hold    t=%0t", $time);
      end
      // ---- c_start_pulse_1cyc：脉冲不得连续两拍 ----
      if (pulse_q && start_pulse) begin
        fail_cnt++;
        $display("[SVA-FAIL] c_start_pulse_1cyc t=%0t", $time);
      end
      // ---- c_busy_no_start：BUSY 期间不得出现 START 脉冲 ----
      if (busy && start_pulse) begin
        fail_cnt++;
        $display("[SVA-FAIL] c_busy_no_start  t=%0t", $time);
      end
      // ---- c_tc_count_match：完成时刻影子计数 == 编程 LEN ----
      if (tc_event && (wbeat_cnt != xfer_len)) begin
        fail_cnt++;
        $display("[SVA-FAIL] c_tc_count_match t=%0t (wbeat=%0d len=%0d)",
                 $time, wbeat_cnt, xfer_len);
      end
      // ---- c_te_stop：错误事件次拍三通道静默 ----
      if (te_q && (arvalid || awvalid || wvalid)) begin
        fail_cnt++;
        $display("[SVA-FAIL] c_te_stop        t=%0t", $time);
      end
      // ---- c_wvalid_notempty：WVALID 时 FIFO 非空 ----
      if (wvalid && (fifo_cnt == 5'd0)) begin
        fail_cnt++;
        $display("[SVA-FAIL] c_wvalid_notempty t=%0t", $time);
      end

      // ---- 历史寄存更新 ----
      arv_q <= arvalid;  arr_q <= arready;
      awv_q <= awvalid;  awr_q <= awready;
      wv_q  <= wvalid;   wr_q  <= wready;
      pulse_q <= start_pulse;
      te_q  <= te_event;
    end
  end

  //---------------------------------------------------------------------------
  // 汇总打印（TB 在 $finish 前调用）
  //---------------------------------------------------------------------------
  task automatic print_summary;
    $display(" SVA Summary : %0d violation(s) across 8 properties", fail_cnt);
    if (fail_cnt == 0) begin
      $display(" [SVA] PASS");
    end else begin
      $display(" [SVA] FAIL");
    end
  endtask

endmodule
