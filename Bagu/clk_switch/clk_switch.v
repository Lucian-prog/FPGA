module clk_switch (
    input wire clk0,
    input wire clk1,
    input wire sel,
    output wire clk_out
);

wire w_DFF0_D;
wire w_DFF1_D;
wire w_clkout_0;
wire w_clkout_1;

reg  r_DFF0_Q;
reg  r_DFF1_Q;

assign w_DFF0_D = !r_DFF1_Q&!sel;
assign w_DFF1_D = !r_DFF0_Q&sel;

always@(negedge clk0)begin
    r_DFF0_Q <= w_DFF0_D;
end

always@(negedge clk1)begin
    r_DFF1_Q <= w_DFF1_D;
end

assign w_clkout_0 = clk0 & r_DFF0_Q;
assign w_clkout_1 = clk1 & r_DFF1_Q;
assign clk_out = w_clkout_0 | w_clkout_1;

endmodule