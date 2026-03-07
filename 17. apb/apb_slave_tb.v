`timescale 1ns / 1ps
// 模块: apb_slave_tb
// 说明: APB Slave 仿真验证
//       测试场景：
//         1. 全字节写 REG_CTRL，读回验证
//         2. PSTRB 字节选通写（只写低字节）
//         3. 只读寄存器 REG_STAT 写忽略验证
//         4. 连续背靠背读写
//         5. 越界地址 PSLVERR 验证

module apb_slave_tb;

  // ── 时钟与复位 ─────────────────────────────────────────
  parameter CLK_PERIOD = 10; // 10ns = 100MHz

  reg         PCLK;
  reg         PRESETn;

  // ── APB 信号 ──────────────────────────────────────────
  reg  [7:0]  PADDR;
  reg         PSEL;
  reg         PENABLE;
  reg         PWRITE;
  reg  [31:0] PWDATA;
  reg  [3:0]  PSTRB;
  wire [31:0] PRDATA;
  wire        PREADY;
  wire        PSLVERR;

  // ── 实例化被测模块 ────────────────────────────────────
  apb_slave #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(8)
  ) u_apb_slave (
    .PCLK    (PCLK),
    .PRESETn (PRESETn),
    .PADDR   (PADDR),
    .PSEL    (PSEL),
    .PENABLE (PENABLE),
    .PWRITE  (PWRITE),
    .PWDATA  (PWDATA),
    .PSTRB   (PSTRB),
    .PRDATA  (PRDATA),
    .PREADY  (PREADY),
    .PSLVERR (PSLVERR)
  );

  // ── 时钟生成 ──────────────────────────────────────────
  initial PCLK = 0;
  always #(CLK_PERIOD/2) PCLK = ~PCLK;

  // ── 任务：APB 写操作 ──────────────────────────────────
  // 按照协议：SETUP(1拍) → ACCESS(1拍，等待PREADY)
  task apb_write;
    input [7:0]  addr;
    input [31:0] data;
    input [3:0]  strb;
    begin
      // SETUP 阶段：拉高 PSEL，保持 PENABLE=0
      @(negedge PCLK);
      PSEL    <= 1'b1;
      PENABLE <= 1'b0;
      PWRITE  <= 1'b1;
      PADDR   <= addr;
      PWDATA  <= data;
      PSTRB   <= strb;

      // ACCESS 阶段：下一时钟拉高 PENABLE，等待 PREADY
      @(negedge PCLK);
      PENABLE <= 1'b1;

      // 等待 PREADY（本设计恒为1，所以只需1个 ACCESS 周期）
      @(posedge PCLK);
      while (!PREADY) @(posedge PCLK);

      // 传输完成，回到 IDLE
      @(negedge PCLK);
      PSEL    <= 1'b0;
      PENABLE <= 1'b0;
      PWRITE  <= 1'b0;
      PADDR   <= 8'h00;
      PWDATA  <= 32'h0;
      PSTRB   <= 4'hF;
    end
  endtask

  // ── 任务：APB 读操作 ──────────────────────────────────
  task apb_read;
    input  [7:0]  addr;
    output [31:0] rdata;
    begin
      // SETUP 阶段
      @(negedge PCLK);
      PSEL    <= 1'b1;
      PENABLE <= 1'b0;
      PWRITE  <= 1'b0;
      PADDR   <= addr;
      PWDATA  <= 32'h0;
      PSTRB   <= 4'hF;

      // ACCESS 阶段
      @(negedge PCLK);
      PENABLE <= 1'b1;

      // 等待 PREADY 并采样读数据
      @(posedge PCLK);
      while (!PREADY) @(posedge PCLK);
      rdata = PRDATA;

      // 回到 IDLE
      @(negedge PCLK);
      PSEL    <= 1'b0;
      PENABLE <= 1'b0;
      PADDR   <= 8'h00;
    end
  endtask

  // ── 测试主逻辑 ────────────────────────────────────────
  reg [31:0] read_data;
  integer    error_count;

  initial begin
    // 初始化信号
    PRESETn    = 1'b0;
    PSEL       = 1'b0;
    PENABLE    = 1'b0;
    PWRITE     = 1'b0;
    PADDR      = 8'h00;
    PWDATA     = 32'h0;
    PSTRB      = 4'hF;
    error_count = 0;

    // ── 复位释放 ──────────────────────────────────────
    repeat(3) @(posedge PCLK);
    @(negedge PCLK);
    PRESETn = 1'b1;
    repeat(2) @(posedge PCLK);

    $display("====================================================");
    $display("[TEST] APB Slave 功能仿真开始");
    $display("====================================================");

    // ─────────────────────────────────────────────────────
    // 场景1：全字节写 REG_CTRL (0x00)，读回验证
    // ─────────────────────────────────────────────────────
    $display("\n[场景1] 全字节写 REG_CTRL = 0xDEADBEEF");
    apb_write(8'h00, 32'hDEADBEEF, 4'hF);

    apb_read(8'h00, read_data);
    if (read_data === 32'hDEADBEEF)
      $display("[PASS] REG_CTRL 读回 = 0x%08X", read_data);
    else begin
      $display("[FAIL] REG_CTRL 期望 0xDEADBEEF，实际 = 0x%08X", read_data);
      error_count = error_count + 1;
    end

    // ─────────────────────────────────────────────────────
    // 场景2：PSTRB 字节选通写（只写低字节 PSTRB=4'b0001）
    // 先将 REG_DATA0 写成全FF，再用选通只改低字节为0xAB
    // 期望结果：0xFFFFFF_AB
    // ─────────────────────────────────────────────────────
    $display("\n[场景2] PSTRB 字节选通写 REG_DATA0");
    apb_write(8'h08, 32'hFFFFFFFF, 4'hF);        // 全字节写FF
    apb_write(8'h08, 32'h000000AB, 4'b0001);      // 只写最低字节

    apb_read(8'h08, read_data);
    if (read_data === 32'hFFFFFFAB)
      $display("[PASS] PSTRB 选通写结果 = 0x%08X", read_data);
    else begin
      $display("[FAIL] 期望 0xFFFFFFAB，实际 = 0x%08X", read_data);
      error_count = error_count + 1;
    end

    // ─────────────────────────────────────────────────────
    // 场景3：只读寄存器 REG_STAT (0x04) 写操作应被忽略
    // REG_STAT 由内部逻辑驱动，写操作静默丢弃
    // ─────────────────────────────────────────────────────
    $display("\n[场景3] 写只读寄存器 REG_STAT，期望被忽略");
    // REG_DATA0 已写入 0xFFFFFFAB（非零），所以 reg_stat[0] 应为1
    apb_read(8'h04, read_data);
    $display("[INFO] 写前 REG_STAT = 0x%08X（bit0=DATA0非零，bit1=DATA1非零）", read_data);

    apb_write(8'h04, 32'hCAFEBABE, 4'hF);        // 写只读寄存器
    apb_read(8'h04, read_data);
    // 内部状态自动维护：DATA0非零→bit0=1，DATA1=0→bit1=0
    if (read_data[0] === 1'b1 && read_data[DATA_WIDTH-1:2] === 0)
      $display("[PASS] REG_STAT 写入被忽略，内部逻辑值正确 = 0x%08X", read_data);
    else begin
      $display("[FAIL] REG_STAT 被意外修改 = 0x%08X", read_data);
      error_count = error_count + 1;
    end

    // ─────────────────────────────────────────────────────
    // 场景4：连续背靠背写 REG_DATA0 和 REG_DATA1
    // ─────────────────────────────────────────────────────
    $display("\n[场景4] 连续写 REG_DATA0 和 REG_DATA1");
    apb_write(8'h08, 32'h12345678, 4'hF);
    apb_write(8'h0C, 32'h9ABCDEF0, 4'hF);

    apb_read(8'h08, read_data);
    if (read_data === 32'h12345678)
      $display("[PASS] REG_DATA0 = 0x%08X", read_data);
    else begin
      $display("[FAIL] REG_DATA0 期望 0x12345678，实际 = 0x%08X", read_data);
      error_count = error_count + 1;
    end

    apb_read(8'h0C, read_data);
    if (read_data === 32'h9ABCDEF0)
      $display("[PASS] REG_DATA1 = 0x%08X", read_data);
    else begin
      $display("[FAIL] REG_DATA1 期望 0x9ABCDEF0，实际 = 0x%08X", read_data);
      error_count = error_count + 1;
    end

    // ─────────────────────────────────────────────────────
    // 场景5：越界地址访问，期望 PSLVERR=1
    // ─────────────────────────────────────────────────────
    $display("\n[场景5] 越界地址访问 PSLVERR 验证");
    // 手动构造一次 ACCESS 阶段，地址为 0x10（超出有效范围）
    @(negedge PCLK);
    PSEL    <= 1'b1;
    PENABLE <= 1'b0;
    PWRITE  <= 1'b0;
    PADDR   <= 8'h10;  // 越界地址
    @(negedge PCLK);
    PENABLE <= 1'b1;
    @(posedge PCLK);
    #1; // 等待输出稳定
    if (PSLVERR === 1'b1)
      $display("[PASS] PSLVERR=1，越界地址正确报错（PADDR=0x10）");
    else begin
      $display("[FAIL] PSLVERR 期望1，实际=%b", PSLVERR);
      error_count = error_count + 1;
    end
    @(negedge PCLK);
    PSEL    <= 1'b0;
    PENABLE <= 1'b0;

    // ─────────────────────────────────────────────────────
    // 仿真结束汇总
    // ─────────────────────────────────────────────────────
    repeat(3) @(posedge PCLK);
    $display("\n====================================================");
    if (error_count == 0)
      $display("[RESULT] 全部测试通过！错误数 = 0");
    else
      $display("[RESULT] 存在失败！错误数 = %0d", error_count);
    $display("====================================================");
    $finish;
  end

  // ── 波形转储（可选，ModelSim / iverilog 均支持） ──────
  initial begin
    $dumpfile("apb_slave_tb.vcd");
    $dumpvars(0, apb_slave_tb);
  end

  // ── 超时保护 ─────────────────────────────────────────
  initial begin
    #50000;
    $display("[TIMEOUT] 仿真超时，强制结束");
    $finish;
  end

  // 声明 DATA_WIDTH，避免 tb 中直接引用参数报错
  localparam DATA_WIDTH = 32;

endmodule
