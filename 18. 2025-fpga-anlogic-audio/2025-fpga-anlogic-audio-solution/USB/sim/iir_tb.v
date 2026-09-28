`timescale 1ns/1ns

module tb();

reg clk=1;
reg rst_n=1;

wire signed [15:0]din;
wire signed [15:0]dout,dout1;
reg [9:0]freq = 2;

dds u_dds(
    .clk(clk),
    .rst_n(rst_n),
    .dds_freq(freq), 
    .ddso(din)
);

iir u_iir_0(
    .clk(clk),
    .rst_n(rst_n),
    .din((din/2)),
    .k1(1773),
    .k2(855),
    .k3(1252),
    .dout(dout)
);
iir u_iir_1(
    .clk(clk),
    .rst_n(rst_n),
    .din(dout),
    .k1(1479),
    .k2(756),
    .k3(1252),
    .dout(dout1)
);

always #10 clk = ~clk;

initial begin
    #200;
    rst_n = 0;
    #200;
    rst_n = 1;
    #100000;
    freq = 26;
    #100000;
    freq = 36;
    #100000;
    freq = 46;
    #100000;
    freq = 56;
    #100000;
    freq = 66;
    #100000;
    freq = 76;
    #100000;
    freq = 86;
    #100000;
    freq = 96;
    #100000;
    freq = 106;
    #100000;
    freq = 116;
    #100000;
    freq = 126;
    #100000;
    $finish;

end


endmodule