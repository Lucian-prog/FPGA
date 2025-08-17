`timescale 1ns / 1ps

module m_sequence_tb;

    // 输入信号
    reg clk;
    reg rst_n;

    // 输出信号
    wire m_seq;

    // 实例化 m_sequence_8bit 模块
    m_sequence_8bit uut (
        .clk(clk),
        .rst_n(rst_n),
        .m_seq(m_seq)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns 周期，即 100MHz 时钟
    end

    // 测试过程
    initial begin
        // 初始化
        rst_n = 0;
        #10;
        rst_n = 1;
        #1000;

        // 结束仿真
        $finish;
    end

    // 监视输出
    initial begin
        $monitor("At time %t, m_seq = %b", $time, m_seq);
    end

endmodule
