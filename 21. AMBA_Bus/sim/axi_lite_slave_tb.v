`timescale 1ns / 1ps
//============================================================================
// axi_lite_slave_tb.v —— AXI4-Lite 从机 testbench
//
// master 行为：negedge 驱动、posedge 采样
// 场景：
//   1. 复位后读默认值
//   2. AW 先到（W 延迟 3 拍）：验证 aw_pend 期间 AWREADY 拉低 + 功能正确
//   3. W 先到（AW 延迟 3 拍）：验证 w_pend 功能正确
//   4. AW 与 W 同拍到达
//   5. WSTRB 部分字节写
//   6. STAT 只读 + 状态位
//   7. BREADY 延迟 5 拍：验证 BVALID 保持 + BVALID 期间 AWREADY/WREADY 拉低
//   8. RREADY 延迟 5 拍：验证 RVALID 保持
//   9. 越界写 → BRESP=SLVERR；越界读 → RRESP=SLVERR + RDATA=0
//  10. 连续混合读写
//============================================================================
module axi_lite_slave_tb;

    localparam TCLK       = 10;    // 100 MHz
    localparam ADDR_WIDTH = 12;

    reg                   ACLK;
    reg                   ARESETn;
    reg  [ADDR_WIDTH-1:0] AWADDR_m;
    reg                   AWVALID_m;
    wire                  AWREADY;
    reg  [31:0]           WDATA_m;
    reg  [3:0]            WSTRB_m;
    reg                   WVALID_m;
    wire                  WREADY;
    wire [1:0]            BRESP;
    wire                  BVALID;
    reg                   BREADY_m;
    reg  [ADDR_WIDTH-1:0] ARADDR_m;
    reg                   ARVALID_m;
    wire                  ARREADY;
    wire [31:0]           RDATA;
    wire [1:0]            RRESP;
    wire                  RVALID;
    reg                   RREADY_m;

    integer errors;

    // 测试主流程使用的暂存变量（须声明在使用之前）
    reg [1:0]  resp_w;
    reg [31:0] rd_d;
    reg [1:0]  resp_r;

    axi_lite_slave #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
        .ACLK(ACLK), .ARESETn(ARESETn),
        .AWADDR(AWADDR_m), .AWPROT(3'b000), .AWVALID(AWVALID_m), .AWREADY(AWREADY),
        .WDATA(WDATA_m), .WSTRB(WSTRB_m), .WVALID(WVALID_m), .WREADY(WREADY),
        .BRESP(BRESP), .BVALID(BVALID), .BREADY(BREADY_m),
        .ARADDR(ARADDR_m), .ARPROT(3'b000), .ARVALID(ARVALID_m), .ARREADY(ARREADY),
        .RDATA(RDATA), .RRESP(RRESP), .RVALID(RVALID), .RREADY(RREADY_m)
    );

    initial ACLK = 1'b0;
    always #(TCLK/2) ACLK = ~ACLK;

    //----------------------------------------------------------------------
    // 检查与通道原语 task
    //----------------------------------------------------------------------
    task check(input [31:0] got, input [31:0] exp, input [255:0] name);
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("[FAIL] %0s: got=%h expected=%h", name, got, exp);
            end else
                $display("[PASS] %0s = %h", name, got);
        end
    endtask

    // 驱动 AW 通道直到握手完成
    task drive_aw(input [ADDR_WIDTH-1:0] addr);
        begin
            @(negedge ACLK);
            AWADDR_m  <= addr;
            AWVALID_m <= 1'b1;
            @(posedge ACLK);
            while (AWREADY !== 1'b1) @(posedge ACLK);
            @(negedge ACLK);
            AWVALID_m <= 1'b0;
        end
    endtask

    // 驱动 W 通道直到握手完成
    task drive_w(input [31:0] data, input [3:0] strb);
        begin
            @(negedge ACLK);
            WDATA_m  <= data;
            WSTRB_m  <= strb;
            WVALID_m <= 1'b1;
            @(posedge ACLK);
            while (WREADY !== 1'b1) @(posedge ACLK);
            @(negedge ACLK);
            WVALID_m <= 1'b0;
        end
    endtask

    // 等待 B 响应；bready_delay>0 时先按住 BREADY 若干拍，
    // 逐拍验证 BVALID 保持、且 BVALID 期间 AWREADY/WREADY 被拉低
    task wait_b(output [1:0] resp, input integer bready_delay);
        integer k;
        begin
            @(posedge ACLK);
            while (BVALID !== 1'b1) @(posedge ACLK);
            for (k = 0; k < bready_delay; k = k + 1) begin
                @(posedge ACLK);
                if (BVALID !== 1'b1) begin
                    errors = errors + 1;
                    $display("[FAIL] BVALID not held while BREADY low");
                end
                if (AWREADY !== 1'b0 || WREADY !== 1'b0) begin
                    errors = errors + 1;
                    $display("[FAIL] AWREADY/WREADY not low while BVALID high");
                end
            end
            resp = BRESP;                          // BVALID=1 期间采样响应
            @(negedge ACLK);
            BREADY_m <= 1'b1;
            @(posedge ACLK);
            while (BVALID !== 1'b0) @(posedge ACLK);
            @(negedge ACLK);
            BREADY_m <= 1'b0;
        end
    endtask

    // 驱动 AR 通道直到握手完成
    task drive_ar(input [ADDR_WIDTH-1:0] addr);
        begin
            @(negedge ACLK);
            ARADDR_m  <= addr;
            ARVALID_m <= 1'b1;
            @(posedge ACLK);
            while (ARREADY !== 1'b1) @(posedge ACLK);
            @(negedge ACLK);
            ARVALID_m <= 1'b0;
        end
    endtask

    // 等待 R 数据；rready_delay>0 时先按住 RREADY 若干拍，验证 RVALID 保持
    task wait_r(output [31:0] data, output [1:0] resp, input integer rready_delay);
        integer k;
        begin
            @(posedge ACLK);
            while (RVALID !== 1'b1) @(posedge ACLK);
            for (k = 0; k < rready_delay; k = k + 1) begin
                @(posedge ACLK);
                if (RVALID !== 1'b1) begin
                    errors = errors + 1;
                    $display("[FAIL] RVALID not held while RREADY low");
                end
            end
            data = RDATA;                          // RVALID=1 期间采样数据
            resp = RRESP;
            @(negedge ACLK);
            RREADY_m <= 1'b1;
            @(posedge ACLK);
            while (RVALID !== 1'b0) @(posedge ACLK);
            @(negedge ACLK);
            RREADY_m <= 1'b0;
        end
    endtask

    //----------------------------------------------------------------------
    // 组合 task
    //----------------------------------------------------------------------
    task axi_write(input [ADDR_WIDTH-1:0] addr, input [31:0] data,
                   input [3:0] strb, output [1:0] resp);
        begin
            drive_aw(addr);
            drive_w(data, strb);
            wait_b(resp, 0);
        end
    endtask

    task axi_read(input [ADDR_WIDTH-1:0] addr, output [31:0] data,
                  output [1:0] resp);
        begin
            drive_ar(addr);
            wait_r(data, resp, 0);
        end
    endtask

    task axi_read_check(input [ADDR_WIDTH-1:0] addr, input [31:0] exp,
                        input [255:0] name);
        reg [31:0] rd;
        reg [1:0]  rp;
        begin
            axi_read(addr, rd, rp);
            check(rd, exp, name);
        end
    endtask

    //----------------------------------------------------------------------
    // 测试主流程
    //----------------------------------------------------------------------
    initial begin
        errors    = 0;
        ARESETn   = 1'b0;
        AWADDR_m  = {ADDR_WIDTH{1'b0}};
        AWVALID_m = 1'b0;
        WDATA_m   = 32'h0;
        WSTRB_m   = 4'h0;
        WVALID_m  = 1'b0;
        BREADY_m  = 1'b0;
        ARADDR_m  = {ADDR_WIDTH{1'b0}};
        ARVALID_m = 1'b0;
        RREADY_m  = 1'b0;

        repeat (3) @(negedge ACLK);
        ARESETn = 1'b1;
        @(negedge ACLK);

        $display("=== Scenario 1: read back after reset ===");
        axi_read_check(12'h000, 32'h0000_0000, "CTRL  after reset");
        axi_read_check(12'h008, 32'h0000_0000, "DATA0 after reset");

        $display("=== Scenario 2: AW first, W delayed by 3 beats ===");
        drive_aw(12'h000);                          // AW 先握手
        if (AWREADY !== 1'b0) begin                 // aw_pend=1：AWREADY 应拉低
            errors = errors + 1;
            $display("[FAIL] AWREADY should be low while waiting for W");
        end else
            $display("[PASS] AWREADY low while waiting for W (aw_pend)");
        repeat (3) @(negedge ACLK);
        drive_w(32'hA5A5_0000, 4'b1111);            // W 3 拍后才到
        wait_b(resp_w, 0);
        check(resp_w, 32'h0, "BRESP OKAY (AW first)");
        axi_read_check(12'h000, 32'hA5A5_0000, "CTRL  after AW-first write");

        $display("=== Scenario 3: W first, AW delayed by 3 beats ===");
        drive_w(32'h1234_5678, 4'b1111);            // W 先握手
        if (WREADY !== 1'b0) begin                  // w_pend=1：WREADY 应拉低
            errors = errors + 1;
            $display("[FAIL] WREADY should be low while waiting for AW");
        end else
            $display("[PASS] WREADY low while waiting for AW (w_pend)");
        repeat (3) @(negedge ACLK);
        drive_aw(12'h008);
        wait_b(resp_w, 0);
        check(resp_w, 32'h0, "BRESP OKAY (W first)");
        axi_read_check(12'h008, 32'h1234_5678, "DATA0 after W-first write");

        $display("=== Scenario 4: AW and W in the same beat ===");
        @(negedge ACLK);
        AWADDR_m  <= 12'h00C;
        AWVALID_m <= 1'b1;
        WDATA_m   <= 32'hDEAD_BEEF;
        WSTRB_m   <= 4'b1111;
        WVALID_m  <= 1'b1;
        @(posedge ACLK);
        while (!(AWREADY === 1'b1 && WREADY === 1'b1)) @(posedge ACLK);
        @(negedge ACLK);
        AWVALID_m <= 1'b0;
        WVALID_m  <= 1'b0;
        wait_b(resp_w, 0);
        check(resp_w, 32'h0, "BRESP OKAY (same beat)");
        axi_read_check(12'h00C, 32'hDEAD_BEEF, "DATA1 after same-beat write");

        $display("=== Scenario 5: WSTRB partial write ===");
        axi_write(12'h000, 32'h0000_FFFF, 4'b0011, resp_w);  // 只写低 2 字节
        axi_read_check(12'h000, 32'hA5A5_FFFF, "CTRL  after WSTRB=0011");

        $display("=== Scenario 6: STAT read-only & status bits ===");
        axi_read_check(12'h004, 32'h0000_0003, "STAT  bits set");
        axi_write(12'h004, 32'hFFFF_FFFF, 4'b1111, resp_w);  // 只读：写忽略
        axi_read_check(12'h004, 32'h0000_0003, "STAT  write-ignored");

        $display("=== Scenario 7: delayed BREADY, BVALID must hold ===");
        drive_aw(12'h008);
        drive_w(32'h5555_AAAA, 4'b1111);
        wait_b(resp_w, 5);                          // BREADY 压 5 拍
        check(resp_w, 32'h0, "BRESP OKAY (delayed BREADY)");
        axi_read_check(12'h008, 32'h5555_AAAA, "DATA0 after delayed BREADY");

        $display("=== Scenario 8: delayed RREADY, RVALID must hold ===");
        drive_ar(12'h000);
        wait_r(rd_d, resp_r, 5);                    // RREADY 压 5 拍
        check(rd_d, 32'hA5A5_FFFF, "RDATA with delayed RREADY");
        check(resp_r, 32'h0, "RRESP OKAY (delayed RREADY)");

        $display("=== Scenario 9: out-of-range SLVERR ===");
        axi_write(12'h010, 32'hFFFF_0000, 4'b1111, resp_w);
        check(resp_w, 32'h2, "BRESP SLVERR (out of range)"); // 2'b10
        drive_ar(12'h014);                          // 越界读
        wait_r(rd_d, resp_r, 0);
        check(resp_r, 32'h2, "RRESP SLVERR (out of range)");
        check(rd_d, 32'h0, "RDATA zero on SLVERR");

        $display("=== Scenario 10: consecutive mixed R/W ===");
        axi_write(12'h008, 32'h0F0F_0F0F, 4'b1111, resp_w);
        axi_write(12'h00C, 32'hF0F0_F0F0, 4'b1111, resp_w);
        axi_read_check(12'h008, 32'h0F0F_0F0F, "DATA0 mixed r/w");
        axi_read_check(12'h00C, 32'hF0F0_F0F0, "DATA1 mixed r/w");
        axi_read_check(12'h000, 32'hA5A5_FFFF, "CTRL  mixed r/w");

        if (errors == 0)
            $display("=== ALL AXI-Lite TESTS PASSED ===");
        else
            $display("=== AXI-Lite TESTS FAILED: %0d errors ===", errors);
        $finish;
    end

    // 波形与超时保护
    initial begin
        $dumpfile("axi_lite_slave_tb.vcd");
        $dumpvars(0, axi_lite_slave_tb);
    end

    initial begin
        #300000;
        $display("[FAIL] TIMEOUT");
        $finish;
    end

endmodule
