// top_tb.sv —— 2.2 复现最终版（对应书上 2.2.4 结束时的形态）
`timescale 1ns/1ns

`include "uvm_macros.svh"
import uvm_pkg::*;      // 2.2.2 引入：run_test 和 UVM 的类都在 uvm_pkg 里

`include "my_if.sv"
`include "my_driver.sv"

module top_tb;

    logic clk;
    logic rst_n;    // 低电平复位，与 dut 的约定一致

    // 50 MHz 时钟，周期 20ns
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // 复位：上电复位 100ns 后释放
    initial begin
        rst_n = 1'b0;
        #100 rst_n = 1'b1;
    end

    // interface 实例发生在 module 世界：clk/rst 通过端口传进去
    my_if input_if(clk, rst_n);

    dut my_dut(
        .clk   (clk),
        .rst_n (rst_n),
        .rxd   (input_if.data),
        .rx_dv (input_if.valid),
        .txd   (),      // 2.2 阶段没人检查输出，先空挂
        .tx_en ()
    );

    initial begin
        // v4 引入：把接口句柄存进 config_db，收件人用绝对路径 uvm_test_top。
        // 树根是 run_test 创建的 my_driver 实例，创建后会被强制改名为 uvm_test_top。
        // set 与 run_test 必须在同一个 initial 块：
        // SV 不保证不同 initial 块的执行顺序，若 run_test 先启动，
        // build_phase 里的 get 会因资源还没 set 而 fatal。
        uvm_config_db#(virtual my_if)::set(null, "uvm_test_top", "vif", input_if);
        run_test("my_driver");
    end

endmodule
