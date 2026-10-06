module mult_pipeline#(
  parameter M=4,
  parameter N=4
)
( input wire clk,
  input wire rst_n,
  input wire mult_en,
  input wire [M-1:0] mult1,
  input wire [N-1:0] mult2,
  output wire mult_valid,
  output wire [M+N-1:0] mult_out
);
  wire [M+N-1:0] mult_shift1 [0:N-1];
  wire [N-1:0] mult_shift2 [0:N-1];
  wire [M+N-1:0] o_mult_acc[0:N-1];
  wire [N-1:0] valid;


  mult_unit #(
    .M(M),
    .N(N)
  )mult0(
    .clk(clk),
    .rst_n(rst_n),
    .mult_en(mult_en),
    .mult1({{N{1'b0}},mult1}),
    .mult2(mult2),
    .mult_shift1(mult_shift1[0]),
    .mult_shift2(mult_shift2[0]),
    .mult_valid(valid[0]),
    .i_mult_acc({(M+N){1'b0}}),
    .o_mult_acc(o_mult_acc[0])
  );
  genvar i;
  generate
    for (i=1; i<N; i=i+1) begin : gen_mult
      mult_unit #(
        .M(M),
        .N(N)
      )mult_i(
        .clk(clk),
        .rst_n(rst_n),
        // 当前级处理上一级的数据，有效标志也必须来自上一级。
        .mult_en(valid[i-1]),
        .mult1(mult_shift1[i-1]),
        .mult2(mult_shift2[i-1]),
        .mult_shift1(mult_shift1[i]),
        .mult_shift2(mult_shift2[i]),
        .mult_valid(valid[i]),
        .i_mult_acc(o_mult_acc[i-1]),
        .o_mult_acc(o_mult_acc[i])
      );
    end
  endgenerate


  assign mult_out=o_mult_acc[N-1];
  assign mult_valid=valid[N-1];

endmodule
