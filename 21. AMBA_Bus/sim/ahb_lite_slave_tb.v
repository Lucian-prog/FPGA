`timescale 1ns / 1ps
//============================================================================
// ahb_lite_slave_tb.v —— AHB-Lite 从机 testbench（对齐 17. apb 的 TB 风格）
//
// master 行为：negedge 驱动、posedge 采样（避免竞争）
// 场景：
//   1. 复位后读默认值
//   2. word 写读回
//   3. byte 写（HSIZE=byte，byte-lane 选通）
//   4. halfword 写（高半字）
//   5. STAT 只读 + 状态位
//   6. SLOW 寄存器：验证数据相位插 1 拍等待
//   7. 越界地址：验证 ERROR 两拍响应（ERR1: HRESP=1+HREADYOUT=0 →
//      ERR2: HRESP=1+HREADYOUT=1）
//   8. 背靠背流水线写（传输 2 的地址相位与传输 1 的数据相位重叠）
//============================================================================
module ahb_lite_slave_tb;

    localparam TCLK       = 10;    // 100 MHz
    localparam ADDR_WIDTH = 12;

    reg                   HCLK;
    reg                   HRESETn;
    reg                   HSEL_m;
    reg  [ADDR_WIDTH-1:0] HADDR_m;
    reg  [1:0]            HTRANS_m;
    reg  [2:0]            HSIZE_m;
    reg                   HWRITE_m;
    reg  [31:0]           HWDATA_m;

    wire [31:0] HRDATA;
    wire        HREADYOUT;
    wire        HRESP;

    // 单从机回环：总线级 HREADY 直接由本从机 HREADYOUT 回传
    wire HREADY = HREADYOUT;

    integer errors;

    ahb_lite_slave #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HSEL(HSEL_m), .HADDR(HADDR_m), .HTRANS(HTRANS_m), .HSIZE(HSIZE_m),
        .HWRITE(HWRITE_m), .HWDATA(HWDATA_m), .HREADY(HREADY),
        .HRDATA(HRDATA), .HREADYOUT(HREADYOUT), .HRESP(HRESP)
    );

    initial HCLK = 1'b0;
    always #(TCLK/2) HCLK = ~HCLK;

    //----------------------------------------------------------------------
    // 检查与 master task
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

    // 单笔写：地址相位 1 拍 + 数据相位（含等待态，while 等 HREADY）
    task ahb_write(input [ADDR_WIDTH-1:0] addr, input [31:0] data, input [2:0] size);
        begin
            @(negedge HCLK);                    // T0：地址相位
            HSEL_m   <= 1'b1;
            HADDR_m  <= addr;
            HTRANS_m <= 2'b10;                  // NONSEQ
            HSIZE_m  <= size;
            HWRITE_m <= 1'b1;
            @(negedge HCLK);                    // T1：数据相位（驱动 HWDATA）
            HWDATA_m <= data;
            HSEL_m   <= 1'b0;
            HTRANS_m <= 2'b00;                  // 后续无传输 → IDLE
            @(posedge HCLK);                    // 等到 HREADY 为高的沿 = 完成沿
            while (HREADY !== 1'b1) @(posedge HCLK);
        end
    endtask

    // 单笔读：完成沿采样 HRDATA
    task ahb_read(input [ADDR_WIDTH-1:0] addr, output [31:0] data);
        begin
            @(negedge HCLK);
            HSEL_m   <= 1'b1;
            HADDR_m  <= addr;
            HTRANS_m <= 2'b10;
            HWRITE_m <= 1'b0;
            HSIZE_m  <= 3'd2;                   // word
            @(negedge HCLK);
            HSEL_m   <= 1'b0;
            HTRANS_m <= 2'b00;
            @(posedge HCLK);
            while (HREADY !== 1'b1) @(posedge HCLK);
            data = HRDATA;                      // 完成沿采样（NBA 更新前，读的是本拍值）
        end
    endtask

    task ahb_read_check(input [ADDR_WIDTH-1:0] addr, input [31:0] exp,
                        input [255:0] name);
        reg [31:0] rd;
        begin
            ahb_read(addr, rd);
            check(rd, exp, name);
        end
    endtask

    // 背靠背流水线写：传输 2 的地址相位与传输 1 的数据相位同拍
    // （T0: A1 地址 | T1: A1 数据 + A2 地址 | T2: A2 数据 —— 每拍完成一笔）
    task ahb_write_b2b(input [ADDR_WIDTH-1:0] a1, input [31:0] d1,
                       input [ADDR_WIDTH-1:0] a2, input [31:0] d2);
        begin
            @(negedge HCLK);
            HSEL_m   <= 1'b1;
            HADDR_m  <= a1;
            HTRANS_m <= 2'b10;
            HWRITE_m <= 1'b1;
            HSIZE_m  <= 3'd2;
            @(negedge HCLK);
            HWDATA_m <= d1;                     // 传输 1 数据相位
            HADDR_m  <= a2;                     // 传输 2 地址相位（流水线重叠！）
            HTRANS_m <= 2'b10;
            @(negedge HCLK);
            HWDATA_m <= d2;
            HSEL_m   <= 1'b0;
            HTRANS_m <= 2'b00;
            @(posedge HCLK);
            while (HREADY !== 1'b1) @(posedge HCLK);
        end
    endtask

    //----------------------------------------------------------------------
    // 测试主流程
    //----------------------------------------------------------------------
    initial begin
        errors   = 0;
        HRESETn  = 1'b0;
        HSEL_m   = 1'b0;
        HADDR_m  = {ADDR_WIDTH{1'b0}};
        HTRANS_m = 2'b00;
        HSIZE_m  = 3'd0;
        HWRITE_m = 1'b0;
        HWDATA_m = 32'h0;

        repeat (3) @(negedge HCLK);
        HRESETn = 1'b1;
        @(negedge HCLK);

        $display("=== Scenario 1: read back after reset ===");
        ahb_read_check(12'h004, 32'h0000_0000, "STAT  after reset");
        ahb_read_check(12'h000, 32'h0000_0000, "CTRL  after reset");
        ahb_read_check(12'h008, 32'h0000_0000, "DATA0 after reset");

        $display("=== Scenario 2: word write read-back ===");
        ahb_write(12'h000, 32'h1234_5678, 3'd2);
        ahb_read_check(12'h000, 32'h1234_5678, "CTRL  word read-back");

        $display("=== Scenario 3: byte write (HSIZE=byte @0x08, lane0) ===");
        ahb_write(12'h008, 32'h0000_00AB, 3'd0);
        ahb_read_check(12'h008, 32'h0000_00AB, "DATA0 byte read-back");

        $display("=== Scenario 4: halfword write (HSIZE=half @0x0E, high half) ===");
        ahb_write(12'h00E, 32'hBEEF_0000, 3'd1);   // 数据按 lane 对齐放在 [31:16]
        ahb_read_check(12'h00C, 32'hBEEF_0000, "DATA1 half read-back");

        $display("=== Scenario 5: STAT status bits & write-ignore ===");
        ahb_read_check(12'h004, 32'h0000_0003, "STAT  bits set");       // DATA0/DATA1 均非零
        ahb_write(12'h004, 32'hFFFF_FFFF, 3'd2);                        // 只读寄存器：写忽略
        ahb_read_check(12'h004, 32'h0000_0003, "STAT  write-ignored");

        $display("=== Scenario 6: SLOW register inserts 1 wait state ===");
        ahb_write(12'h010, 32'hCAFE_0001, 3'd2);   // 经 task 内 while 完成等待
        ahb_read_check(12'h010, 32'hCAFE_0001, "SLOW write read-back");
        // 手动驱动一笔 SLOW 读，逐拍检查等待插入
        @(negedge HCLK);
        HSEL_m   <= 1'b1;
        HADDR_m  <= 12'h010;
        HTRANS_m <= 2'b10;
        HWRITE_m <= 1'b0;
        HSIZE_m  <= 3'd2;
        @(negedge HCLK);
        HSEL_m   <= 1'b0;
        HTRANS_m <= 2'b00;
        @(posedge HCLK);                           // 数据相位第 1 拍：应为等待拍
        if (HREADYOUT !== 1'b0 || HRESP !== 1'b0) begin
            errors = errors + 1;
            $display("[FAIL] SLOW wait beat: HREADYOUT=%b HRESP=%b (exp 0/0)",
                     HREADYOUT, HRESP);
        end else
            $display("[PASS] SLOW wait beat (HREADYOUT=0)");
        @(posedge HCLK);                           // 数据相位第 2 拍：完成，读数据有效
        if (HREADYOUT !== 1'b1) begin
            errors = errors + 1;
            $display("[FAIL] SLOW complete beat: HREADYOUT=%b (exp 1)", HREADYOUT);
        end else
            $display("[PASS] SLOW complete beat (HREADYOUT=1)");
        check(HRDATA, 32'hCAFE_0001, "SLOW read data");
        @(negedge HCLK);

        $display("=== Scenario 7: out-of-range ERROR two-beat response ===");
        @(negedge HCLK);
        HSEL_m   <= 1'b1;
        HADDR_m  <= 12'h014;                       // 越界地址
        HTRANS_m <= 2'b10;
        HWRITE_m <= 1'b1;
        HSIZE_m  <= 3'd2;
        @(negedge HCLK);
        HWDATA_m <= 32'hDEAD_BEEF;
        HSEL_m   <= 1'b0;
        HTRANS_m <= 2'b00;
        @(posedge HCLK);                           // 数据相位第 1 拍：ERR1
        if (HRESP !== 1'b1 || HREADYOUT !== 1'b0) begin
            errors = errors + 1;
            $display("[FAIL] ERROR beat1: HRESP=%b HREADYOUT=%b (exp 1/0)",
                     HRESP, HREADYOUT);
        end else
            $display("[PASS] ERROR beat1 (HRESP=1, HREADYOUT=0)");
        @(posedge HCLK);                           // 数据相位第 2 拍：ERR2 完成
        if (HRESP !== 1'b1 || HREADYOUT !== 1'b1) begin
            errors = errors + 1;
            $display("[FAIL] ERROR beat2: HRESP=%b HREADYOUT=%b (exp 1/1)",
                     HRESP, HREADYOUT);
        end else
            $display("[PASS] ERROR beat2 (HRESP=1, HREADYOUT=1)");
        @(negedge HCLK);

        $display("=== Scenario 8: back-to-back pipelined writes ===");
        ahb_write_b2b(12'h008, 32'h1111_2222, 12'h00C, 32'h3333_4444);
        ahb_read_check(12'h008, 32'h1111_2222, "b2b DATA0 read-back");
        ahb_read_check(12'h00C, 32'h3333_4444, "b2b DATA1 read-back");

        if (errors == 0)
            $display("=== ALL AHB-Lite TESTS PASSED ===");
        else
            $display("=== AHB-Lite TESTS FAILED: %0d errors ===", errors);
        $finish;
    end

    // 波形与超时保护
    initial begin
        $dumpfile("ahb_lite_slave_tb.vcd");
        $dumpvars(0, ahb_lite_slave_tb);
    end

    initial begin
        #200000;
        $display("[FAIL] TIMEOUT");
        $finish;
    end

endmodule
