`timescale 1ns/1ps

//=============================================================================
// tb_dma_regs —— dma_regs（AXI4-Lite 寄存器组）自检测试平台
//
// DUT 协议要点（简化 AXI4-Lite）：
//   - 无 bready/rready 端口，bvalid/rvalid 为单拍脉冲
//   - awready/wready/arready 常高
//   - 非法偏移访问返回 SLVERR，且不挂死（BFM 内置 500 拍响应超时保护）
//   - busy_i=1 期间写被忽略，但握手照常返回 OKAY
//   - CTRL.START 写 1 后 1 拍内出 start_pulse_o 脉冲，2 拍内自清
//   - tc/te 事件脉冲置中断标志，ICR(0x14) 写 1 清除，irq = 标志 & IE
//
// 用例：
//   T1 复位值   T2 RW 读写回   T3 START 自清
//   T4 中断 W1C T5 非法偏移   T6 BUSY 写保护
//
// 竞争规避：TB 驱动的 DUT 输入（busy_i/tc_event_i/te_event_i 等）统一在
// negedge clk 变化，保证 DUT 在 posedge 恰好采样到预期电平。
//=============================================================================

module tb_dma_regs;

  import dma_pkg::*;

  //---------------------------------------------------------------------------
  // 参数与期望值常量（全部由包内位域常量构造，不硬编码魔法数字）
  //---------------------------------------------------------------------------
  localparam int CLK_PERIOD_NS = 10;  // 100MHz

  // T2: CTRL = EN | IE_TC | BURST=2（即 0x109）
  localparam logic [31:0] EXP_CTRL_RW = (32'd1 << CTRL_EN) |
                                        (32'd1 << CTRL_IE_TC) |
                                        (32'd2 << CTRL_BURST_LSB);
  // T3: CTRL = EN | START（即 0x003），自清后仅剩 EN（即 0x001）
  localparam logic [31:0] EXP_CTRL_START   = (32'd1 << CTRL_EN) |
                                             (32'd1 << CTRL_START);
  localparam logic [31:0] EXP_CTRL_EN_ONLY = 32'd1 << CTRL_EN;
  // T4: CTRL = IE_TC | IE_TE
  localparam logic [31:0] EXP_CTRL_IE_ALL = (32'd1 << CTRL_IE_TC) |
                                            (32'd1 << CTRL_IE_TE);
  localparam logic [31:0] ICR_CLR_ALL = 32'h0000_0003;  // bit0 清 TC 标志 / bit1 清 TE 标志
  localparam logic [31:0] BAD_ADDR    = 32'h0000_0018;  // ICR(0x14) 之后第一个非法偏移
  localparam logic [31:0] LEN_SNEAK   = 32'hCAFE_0000;  // busy 期间尝试偷写的 LEN 值
  localparam logic [31:0] EXP_SRC = 32'hDEAD_BEEF;
  localparam logic [31:0] EXP_DST = 32'h1234_5678;
  localparam logic [31:0] EXP_LEN = 32'd64;

  //---------------------------------------------------------------------------
  // 信号
  //---------------------------------------------------------------------------
  logic clk;
  logic rst_n;

  // AXI4-Lite 总线（BFM <-> DUT 直连）
  logic [31:0] s_axil_awaddr;
  logic [2:0]  s_axil_awprot;
  logic        s_axil_awvalid;
  logic        s_axil_awready;
  logic [31:0] s_axil_wdata;
  logic [3:0]  s_axil_wstrb;
  logic        s_axil_wvalid;
  logic        s_axil_wready;
  logic [1:0]  s_axil_bresp;
  logic        s_axil_bvalid;
  logic [31:0] s_axil_araddr;
  logic        s_axil_arvalid;
  logic        s_axil_arready;
  logic [31:0] s_axil_rdata;
  logic [1:0]  s_axil_rresp;
  logic        s_axil_rvalid;

  // DUT 寄存器输出（TB 监视）
  logic [31:0] src_o;
  logic [31:0] dst_o;
  logic [31:0] len_o;
  logic        ctrl_en_o;
  logic [2:0]  ctrl_burst_o;
  logic        ctrl_ie_tc_o;
  logic        ctrl_ie_te_o;

  // DUT 状态输入（TB 驱动，统一 negedge 变化）
  logic        busy_i;
  logic        done_i;
  logic [1:0]  errcode_i;
  logic        tc_event_i;
  logic        te_event_i;

  // DUT 事件/中断输出（TB 监视）
  logic        start_pulse_o;
  logic        irq_tc_o;
  logic        irq_te_o;

  // 测试统计与读数据缓存
  int          test_cnt = 0;
  int          pass_cnt = 0;
  int          fail_cnt = 0;
  string       fail_names [32];
  int          fail_idx  = 0;
  logic [31:0] rd_data;
  logic [31:0] old_len;
  int          pulse_before;

  //---------------------------------------------------------------------------
  // 时钟 / 复位
  //---------------------------------------------------------------------------
  initial clk = 1'b0;
  always #(CLK_PERIOD_NS/2) clk = ~clk;

  //---------------------------------------------------------------------------
  // BFM / DUT 例化（端口名与 dma_regs 定义逐字一致）
  //---------------------------------------------------------------------------
  axi_lite_bfm u_bfm (
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
    .s_axil_rvalid  (s_axil_rvalid)
  );

  dma_regs u_dut (
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
    .src_o          (src_o),
    .dst_o          (dst_o),
    .len_o          (len_o),
    .ctrl_en_o      (ctrl_en_o),
    .ctrl_burst_o   (ctrl_burst_o),
    .ctrl_ie_tc_o   (ctrl_ie_tc_o),
    .ctrl_ie_te_o   (ctrl_ie_te_o),
    .busy_i         (busy_i),
    .done_i         (done_i),
    .errcode_i      (errcode_i),
    .tc_event_i     (tc_event_i),
    .te_event_i     (te_event_i),
    .start_pulse_o  (start_pulse_o),
    .irq_tc_o       (irq_tc_o),
    .irq_te_o       (irq_te_o)
  );

  //---------------------------------------------------------------------------
  // start_pulse_o 监视器
  //   start_pulse_cnt : 累计脉冲个数（每个为高的采样沿 +1）
  //   start_wid_err   : 出现连续两拍高 -> 非单拍脉冲，置 1 报错
  //---------------------------------------------------------------------------
  int   start_pulse_cnt;
  logic start_pulse_d;
  logic start_wid_err;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_pulse_cnt <= 0;
      start_pulse_d   <= 1'b0;
      start_wid_err   <= 1'b0;
    end else begin
      start_pulse_d <= start_pulse_o;
      if (start_pulse_o) begin
        start_pulse_cnt <= start_pulse_cnt + 1;
        if (start_pulse_d) start_wid_err <= 1'b1;
      end
    end
  end

  //---------------------------------------------------------------------------
  // 自检 helper：关键比对一律用 ===（可识别 X/Z）
  //---------------------------------------------------------------------------
  task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
    test_cnt++;
    if (got === exp) begin
      pass_cnt++;
      $display("[PASS] %0s : 0x%08h", name, got);
    end else begin
      fail_cnt++;
      fail_names[fail_idx] = name;
      fail_idx++;
      $display("[FAIL] %0s : exp=0x%08h got=0x%08h  @%0t", name, exp, got, $time);
    end
  endtask

  // 单 bit 版本（打印二进制更直观）
  task automatic check1(input string name, input logic got, input logic exp);
    test_cnt++;
    if (got === exp) begin
      pass_cnt++;
      $display("[PASS] %0s : %0b", name, got);
    end else begin
      fail_cnt++;
      fail_names[fail_idx] = name;
      fail_idx++;
      $display("[FAIL] %0s : exp=%0b got=%0b  @%0t", name, exp, got, $time);
    end
  endtask

  //---------------------------------------------------------------------------
  // DUT 输入驱动辅助任务（全部 negedge 变化，保证 DUT 采样确定性）
  //---------------------------------------------------------------------------
  // 发 1 拍 tc_event_i 脉冲（恰好跨越一个 posedge）
  task automatic pulse_tc_event();
    @(negedge clk);
    tc_event_i = 1'b1;
    @(negedge clk);
    tc_event_i = 1'b0;
  endtask

  // 发 1 拍 te_event_i 脉冲
  task automatic pulse_te_event();
    @(negedge clk);
    te_event_i = 1'b1;
    @(negedge clk);
    te_event_i = 1'b0;
  endtask

  // 修改 busy_i
  task automatic set_busy(input logic val);
    @(negedge clk);
    busy_i = val;
  endtask

  //---------------------------------------------------------------------------
  // 主测试序列
  //---------------------------------------------------------------------------
  initial begin
    $display("=================================================");
    $display(" tb_dma_regs : dma_regs self-check testbench");
    $display("=================================================");

    // 输入初始化
    busy_i     = 1'b0;
    done_i     = 1'b0;
    errcode_i  = ERR_NONE;
    tc_event_i = 1'b0;
    te_event_i = 1'b0;

    // 复位：低 5 拍后在 negedge 释放（避免与采样沿竞争）
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    //=========================================================================
    // T1: 复位值 —— 全部寄存器读回应为 0
    //=========================================================================
    $display("\n--- T1: reset values ---");
    u_bfm.axil_read(REG_SRC,    rd_data); check("T1 SRC reset",    rd_data, 32'h0);
    u_bfm.axil_read(REG_DST,    rd_data); check("T1 DST reset",    rd_data, 32'h0);
    u_bfm.axil_read(REG_LEN,    rd_data); check("T1 LEN reset",    rd_data, 32'h0);
    u_bfm.axil_read(REG_CTRL,   rd_data); check("T1 CTRL reset",   rd_data, 32'h0);
    u_bfm.axil_read(REG_STATUS, rd_data); check("T1 STATUS reset", rd_data, 32'h0);
    u_bfm.axil_read(REG_ICR,    rd_data); check("T1 ICR read-as-0", rd_data, 32'h0);
    // 合法地址读响应应为 OKAY（以最后一次读为准）
    check("T1 rd_resp OKAY", {30'b0, u_bfm.rd_resp}, {30'b0, AXI_RESP_OKAY});
    check1("T1 rd no timeout", u_bfm.rd_timeout, 1'b0);

    //=========================================================================
    // T2: RW 写读回 + 寄存器输出端口检查
    //=========================================================================
    $display("\n--- T2: RW write & readback ---");
    u_bfm.axil_write(REG_SRC,  EXP_SRC);
    u_bfm.axil_write(REG_DST,  EXP_DST);
    u_bfm.axil_write(REG_LEN,  EXP_LEN);
    u_bfm.axil_write(REG_CTRL, EXP_CTRL_RW);
    // 合法地址写响应应为 OKAY（以最后一次写为准）
    check("T2 wr_resp OKAY", {30'b0, u_bfm.wr_resp}, {30'b0, AXI_RESP_OKAY});
    check1("T2 wr no timeout", u_bfm.wr_timeout, 1'b0);

    // 输出端口应在写后 1 拍内更新，等 2 拍后检查
    repeat (2) @(posedge clk);
    check ("T2 src_o",        src_o,        EXP_SRC);
    check ("T2 dst_o",        dst_o,        EXP_DST);
    check ("T2 len_o",        len_o,        EXP_LEN);
    check1("T2 ctrl_en_o",    ctrl_en_o,    1'b1);
    check ("T2 ctrl_burst_o", {29'b0, ctrl_burst_o}, 32'd2);
    check1("T2 ctrl_ie_tc_o", ctrl_ie_tc_o, 1'b1);
    check1("T2 ctrl_ie_te_o", ctrl_ie_te_o, 1'b0);

    // 读回比对
    u_bfm.axil_read(REG_SRC,  rd_data); check("T2 SRC readback",  rd_data, EXP_SRC);
    u_bfm.axil_read(REG_DST,  rd_data); check("T2 DST readback",  rd_data, EXP_DST);
    u_bfm.axil_read(REG_LEN,  rd_data); check("T2 LEN readback",  rd_data, EXP_LEN);
    u_bfm.axil_read(REG_CTRL, rd_data); check("T2 CTRL readback", rd_data, EXP_CTRL_RW);

    //=========================================================================
    // T3: START 自清 —— 恰好 1 拍脉冲，2 拍内 START 位清零
    //=========================================================================
    $display("\n--- T3: START self-clear ---");
    @(negedge clk);
    pulse_before = start_pulse_cnt;   // negedge 快照，计数器值已稳定
    u_bfm.axil_write(REG_CTRL, EXP_CTRL_START);  // EN | START
    repeat (6) @(posedge clk);        // 覆盖"1 拍内出脉冲、2 拍内自清"窗口
    check ("T3 start pulse count == 1", start_pulse_cnt, pulse_before + 1);
    check1("T3 start pulse 1-cycle wide", start_wid_err, 1'b0);
    u_bfm.axil_read(REG_CTRL, rd_data);
    check("T3 CTRL after self-clear", rd_data, EXP_CTRL_EN_ONLY);  // 仅剩 EN

    //=========================================================================
    // T4: 中断 W1C —— 事件置位、ICR 写 1 清除、IE 关闭时不产生 irq
    //=========================================================================
    $display("\n--- T4: interrupt W1C ---");
    u_bfm.axil_write(REG_CTRL, EXP_CTRL_IE_ALL);  // 使能 IE_TC / IE_TE

    pulse_tc_event();                 // TC 事件脉冲 -> irq_tc 置位
    repeat (2) @(posedge clk);
    check1("T4 irq_tc set by tc_event", irq_tc_o, 1'b1);

    pulse_te_event();                 // TE 事件脉冲 -> irq_te 置位
    repeat (2) @(posedge clk);
    check1("T4 irq_te set by te_event", irq_te_o, 1'b1);

    u_bfm.axil_write(REG_ICR, ICR_CLR_ALL);  // W1C 清除两个标志
    repeat (2) @(posedge clk);
    check1("T4 irq_tc cleared by ICR", irq_tc_o, 1'b0);
    check1("T4 irq_te cleared by ICR", irq_te_o, 1'b0);

    u_bfm.axil_write(REG_CTRL, 32'h0);  // 关闭全部 IE
    pulse_tc_event();
    pulse_te_event();
    repeat (2) @(posedge clk);
    check1("T4 no irq_tc when IE off", irq_tc_o, 1'b0);
    check1("T4 no irq_te when IE off", irq_te_o, 1'b0);

    u_bfm.axil_write(REG_ICR, ICR_CLR_ALL);  // 清掉可能残留的标志，恢复干净状态

    //=========================================================================
    // T5: 非法偏移 —— 写/读均回 SLVERR，且不挂死（BFM 超时保护）
    //=========================================================================
    $display("\n--- T5: illegal offset SLVERR ---");
    u_bfm.axil_write(BAD_ADDR, 32'h0);
    check ("T5 wr_resp SLVERR", {30'b0, u_bfm.wr_resp}, {30'b0, AXI_RESP_SLVERR});
    check1("T5 wr no timeout",  u_bfm.wr_timeout, 1'b0);

    u_bfm.axil_read(BAD_ADDR, rd_data);
    check ("T5 rd_resp SLVERR", {30'b0, u_bfm.rd_resp}, {30'b0, AXI_RESP_SLVERR});
    check1("T5 rd no timeout",  u_bfm.rd_timeout, 1'b0);

    // 非法访问不应破坏既有寄存器内容
    u_bfm.axil_read(REG_SRC, rd_data);
    check("T5 SRC intact after bad access", rd_data, EXP_SRC);

    //=========================================================================
    // T6: BUSY 写保护 —— busy 期间写被忽略，但握手照常 OKAY
    //     （顺带把 BFM 的 write_gap 配置为 1，覆盖带间隔的写路径）
    //=========================================================================
    $display("\n--- T6: BUSY write protection ---");
    u_bfm.axil_read(REG_LEN, old_len);          // 记录当前 LEN 作为期望保持值

    u_bfm.write_gap = 1;                        // 写前后各插 1 拍空闲
    set_busy(1'b1);
    u_bfm.axil_write(REG_LEN, LEN_SNEAK);       // busy 期间偷写
    check ("T6 busy write resp OKAY", {30'b0, u_bfm.wr_resp}, {30'b0, AXI_RESP_OKAY});
    set_busy(1'b0);
    u_bfm.write_gap = 0;                        // 恢复默认

    repeat (2) @(posedge clk);
    u_bfm.axil_read(REG_LEN, rd_data);
    check("T6 LEN unchanged during busy", rd_data, old_len);

    //=========================================================================
    // 结束汇总
    //=========================================================================
    $display("\n=================================================");
    $display(" Test Summary : %0d/%0d checks passed", pass_cnt, test_cnt);
    if (fail_cnt == 0) begin
      $display("[FINISH] PASS");
    end else begin
      $display("[FINISH] FAIL");
      $display(" Failed checks (%0d):", fail_cnt);
      for (int i = 0; i < fail_idx; i++) begin
        $display("   - %0s", fail_names[i]);
      end
    end
    $display("=================================================");
    $finish;
  end

  //---------------------------------------------------------------------------
  // 全局超时看门狗：任何挂死在此兜底，判 FAIL
  //---------------------------------------------------------------------------
  initial begin
    #200_000;  // 200us
    $display("[ERROR] global timeout @%0t, testbench hung.", $time);
    $display("[FINISH] FAIL");
    $finish;
  end

endmodule
