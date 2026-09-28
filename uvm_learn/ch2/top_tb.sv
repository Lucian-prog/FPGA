// 2.5：验证平台顶层
`timescale 1ns/1ps

`include "uvm_macros.svh"

import uvm_pkg::*;

// include 顺序：被依赖的类先出现
`include "my_if.sv"
`include "my_transaction.sv"
`include "my_sequencer.sv"
`include "my_sequence.sv"
`include "my_driver.sv"
`include "my_monitor.sv"
`include "my_agent.sv"
`include "my_model.sv"
`include "my_scoreboard.sv"
`include "my_env.sv"
`include "base_test.sv"

module top_tb;

    logic       clk;
    logic       rst_n;
    logic [7:0] rxd;
    logic       rx_dv;
    logic [7:0] txd;
    logic       tx_en;

    // 输入 / 输出两侧各挂一个 interface
    my_if input_if(clk, rst_n);
    my_if output_if(clk, rst_n);

    dut my_dut(.clk  (clk),
               .rst_n(rst_n),
               .rxd  (input_if.data),
               .rx_dv(input_if.valid),
               .txd  (output_if.data),
               .tx_en(output_if.valid));

    initial begin
        clk = 0;
        forever begin
            #100 clk = ~clk;
        end
    end

    initial begin
        rst_n = 1'b0;
        #1000;
        rst_n = 1'b1;
    end

    // set 与 run_test 必须放在同一个 initial 块里：
    // SV 不保证不同 initial 之间的执行顺序，若 run_test 先执行，
    // build_phase 在 t=0 的 get 会因资源尚未 set 而 fatal
    initial begin
        // set 的路径是正则语义：i_agt* 同时匹配 i_agt.drv / i_agt.mon
        uvm_config_db#(virtual my_if)::set(null, "uvm_test_top.env.i_agt*", "vif", input_if);
        uvm_config_db#(virtual my_if)::set(null, "uvm_test_top.env.o_agt*", "vif", output_if);
        run_test("my_case0");
    end

endmodule
