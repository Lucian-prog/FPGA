(* multstyle = "logic" *)
module iir(
input clk,
input rst_n,
input signed [15:0]din,
input signed [15:0]k1,
input signed [15:0]k2,
input signed [15:0]k3,
output reg signed [15:0]dout

);

reg signed [40:0]cache1,cache2,cache3;
wire signed [56:0]mult_k1_raw;
wire signed [56:0]mult_k2_raw;
wire signed [56:0]mult_k3_raw;
DSP u_dsp_k1(
    .a(cache1),
    .b(k1),
    .p(mult_k1_raw)
);
DSP u_dsp_k2(
    .a(cache2),
    .b(k2),
    .p(mult_k2_raw)
);
DSP u_dsp_k3(
    .a(cache1 - cache3),
    .b(k3),
    .p(mult_k3_raw)
);
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cache1 <= 0;
        cache2 <= 0;
        cache3 <= 0;
        dout <= 0;
    end else begin
        cache1 <= din + mult_k1_raw/1024 - mult_k2_raw/1024;
        cache2 <= cache1;
        cache3 <= cache2;
        dout <= mult_k3_raw/8192;
    end
end




endmodule