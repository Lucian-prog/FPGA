module iir_ch(
input clk,
input rst_n,
input signed [15:0]din,
input signed [15:0]k1,
input signed [15:0]k2,
input signed [15:0]k3,
output reg signed [15:0]dout

);

reg signed [41:0]cache1,cache2,cache3;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cache1 <= 0;
        cache2 <= 0;
        cache3 <= 0;
        dout <= 0;
    end else begin
        cache1 <= din + cache1* k1/4096 - cache2 * k2/4096;
        cache2 <= cache1;
        cache3 <= cache2;
        dout <= (cache1 - cache3)*k3/65536;
    end
end




endmodule