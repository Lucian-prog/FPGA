// dut.sv —— 书上清单 2-1
// 最简单的直通 DUT：输入打一拍输出
`timescale 1ns/1ns

module dut(
    input             clk,
    input             rst_n,   // 低电平复位
    input  [7:0]      rxd,
    input             rx_dv,
    output reg [7:0]  txd,
    output reg        tx_en
);

    always @(posedge clk) begin
        if (!rst_n) begin
            txd   <= 8'b0;
            tx_en <= 1'b0;
        end
        else begin
            txd   <= rxd;    // 输入打一拍直通到输出
            tx_en <= rx_dv;
        end
    end

endmodule
