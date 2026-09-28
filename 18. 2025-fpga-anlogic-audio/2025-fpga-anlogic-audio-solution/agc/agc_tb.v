`timescale 1ns/1ns

module tb;

reg clk=1;
reg rst_n=1;

reg [9:0]dds_freq = 20;

reg signed [15:0]exp_amp;
reg signed [7:0]amp;

wire signed [15:0]ddso;
wire signed [23:0]dds_amp_o;

assign dds_amp_o = ddso * amp;

wire signed [15:0]agc_dout;

dds dds0(
    .clk(clk),
    .rst_n(rst_n),
    .dds_freq(dds_freq),
    .ddso(ddso)
);

agc uut(
    .clk(clk),
    .rst_n(rst_n),
    .din(dds_amp_o),
    .exp_amp(exp_amp),
    .dout(agc_dout)
);

always #10 clk = !clk;

initial begin
    #200;
    rst_n = 0;
    amp = 32;
    exp_amp = 7000;
    #200;
    rst_n = 1;
    #1000000;
    $finish;
    
end


endmodule