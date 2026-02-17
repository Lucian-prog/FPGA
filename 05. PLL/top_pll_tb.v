`timescale 1ns/1ps
//================================================================
// top_pll_tb.v - PLL模块测试平台
// 测试场景:
//   1. 基础功能测试 - NCO频率控制
//   2. 锁定测试 - PLL跟踪输入信号
//   3. 频率跳变测试 - 跟踪频率变化
//================================================================
module top_pll_tb;

    // 时钟和复位
    reg        sys_clk;
    reg        reset;
    
    // 参考信号输入
    reg        A;
    
    // 输出
    wire       B;
    wire [31:0] freq;
    wire       locked;
    wire [31:0] phase_out;
    
    // 时钟生成 (50MHz)
    initial begin
        sys_clk = 0;
        forever #10 sys_clk = ~sys_clk;  // 20ns周期 = 50MHz
    end
    
    // 参考信号A生成 (可调频率)
    reg [31:0] a_period_count;
    reg [31:0] a_period_target;
    
    initial begin
        a_period_target = 32'd250;  // 初始: 50MHz/250 = 200kHz
        a_period_count = 0;
        A = 0;
    end
    
    always @(posedge sys_clk) begin
        a_period_count <= a_period_count + 1;
        if (a_period_count >= a_period_target) begin
            A <= ~A;
            a_period_count <= 0;
        end
    end
    
    // 实例化DUT
    top_pll uut (
        .sys_clk    (sys_clk),
        .reset      (reset),
        .A          (A),
        .B          (B),
        .freq       (freq),
        .locked     (locked),
        .phase_out  (phase_out)
    );
    
    // 测试控制
    initial begin
        $dumpfile("top_pll_tb.vcd");
        $dumpvars(0, top_pll_tb);
        
        // 初始化
        reset = 1;
        #100;
        reset = 0;
        #100;
        
        $display("========================================");
        $display("PLL Test Start");
        $display("========================================");
        
        // 测试1: 等待锁定
        $display("[%0t] Wait for initial lock...", $time);
        #500000;  // 10ms
        
        if (locked) begin
            $display("[%0t] PLL Locked! Frequency = %0d Hz", $time, freq);
        end else begin
            $display("[%0t] PLL not locked yet", $time);
        end
        
        // 测试2: 频率跳变 - 增加到220kHz
        $display("[%0t] Frequency jump to 220kHz...", $time);
        a_period_target = 32'd227;  // 50MHz/227 ≈ 220kHz
        #1000000;  // 20ms
        
        if (locked) begin
            $display("[%0t] Re-locked! Frequency = %0d Hz", $time, freq);
        end
        
        // 测试3: 频率跳变 - 增加到240kHz
        $display("[%0t] Frequency jump to 240kHz...", $time);
        a_period_target = 32'd208;  // 50MHz/208 ≈ 240kHz
        #1000000;
        
        // 测试4: 频率跳变 - 降低到180kHz
        $display("[%0t] Frequency jump to 180kHz...", $time);
        a_period_target = 32'd278;  // 50MHz/278 ≈ 180kHz
        #1000000;
        
        $display("========================================");
        $display("PLL Test Complete");
        $display("========================================");
        
        #100000;
        $finish;
    end
    
    // 监控输出
    always @(posedge sys_clk) begin
        if (locked && ($time > 1000000)) begin
            $display("[%0t] Locked! B=%b, Freq=%0d Hz", $time, B, freq);
        end
    end

endmodule
