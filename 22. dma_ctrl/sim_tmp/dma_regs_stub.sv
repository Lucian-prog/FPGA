//=============================================================================
// dma_regs_stub.sv —— dma_regs 编译自检桩（非交付物！）
//
// 仅用于 tb/axi_lite_bfm.sv + tb/tb_dma_regs.sv 的 iverilog 语法自检，
// 无任何功能行为。三个 ready 常高是为了万一误跑时 BFM 握手不挂死，
// bvalid/rvalid 恒 0 会让 BFM 触发响应超时路径，属预期。
// 不得拷入 tb/ 或 rtl/ 目录。
//=============================================================================

module dma_regs (
  input  logic        clk,
  input  logic        rst_n,
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
  output logic [31:0] src_o,
  output logic [31:0] dst_o,
  output logic [31:0] len_o,
  output logic        ctrl_en_o,
  output logic [2:0]  ctrl_burst_o,
  output logic        ctrl_ie_tc_o,
  output logic        ctrl_ie_te_o,
  input  logic        busy_i,
  input  logic        done_i,
  input  logic [1:0]  errcode_i,
  input  logic        tc_event_i,
  input  logic        te_event_i,
  output logic        start_pulse_o,
  output logic        irq_tc_o,
  output logic        irq_te_o
);

  // 纯组合拉常值，仅供编译通过
  assign s_axil_awready = 1'b1;
  assign s_axil_wready  = 1'b1;
  assign s_axil_arready = 1'b1;
  assign s_axil_bresp   = 2'b00;
  assign s_axil_bvalid  = 1'b0;
  assign s_axil_rdata   = 32'b0;
  assign s_axil_rresp   = 2'b00;
  assign s_axil_rvalid  = 1'b0;
  assign src_o          = 32'b0;
  assign dst_o          = 32'b0;
  assign len_o          = 32'b0;
  assign ctrl_en_o      = 1'b0;
  assign ctrl_burst_o   = 3'b000;
  assign ctrl_ie_tc_o   = 1'b0;
  assign ctrl_ie_te_o   = 1'b0;
  assign start_pulse_o  = 1'b0;
  assign irq_tc_o       = 1'b0;
  assign irq_te_o       = 1'b0;

  // 未使用的输入，显式引用一下避免部分工具的 unused 告警
  logic unused_ok;
  assign unused_ok = clk & rst_n & s_axil_awaddr[0] & (s_axil_awprot[0] | s_axil_awvalid)
                   | s_axil_wdata[0] & s_axil_wstrb[0] & s_axil_wvalid
                   | s_axil_araddr[0] & s_axil_arvalid
                   | busy_i & done_i & errcode_i[0]
                   | tc_event_i & te_event_i;

endmodule
