module mult #(
    parameter M = 4,
    parameter N = 4
) (
    input wire clk,
    input wire rst_n,
    input wire mult_en,
    input wire [M-1:0] mult1,
    input wire [N-1:0] mult2,
    output reg mult_out_valid,
    output reg [M+N-1:0] mult_out
);
  reg [M+N-1:0] mult_shift1;
  reg [N-1:0] mult_shift2;
  reg [M+N-1:0] mult_acc;
  reg [31:0] cnt;

  // mult_en 必须保持到 cnt=N 输出结果；中途拉低表示取消本次计算。
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 0;
    end else if (mult_en) begin
      if (cnt < N) begin
        cnt <= cnt + 1;
      end
      if (cnt == N) begin
        cnt <= 0;
      end
    end else begin
      cnt <= 0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mult_shift1 <= 0;
      mult_shift2 <= 0;
      mult_acc <= 0;
      mult_out <= 0;
      mult_out_valid <= 1'b0;
    end else begin
      // 仅在完成周期产生有效脉冲，空闲和运算周期均清零。
      mult_out_valid <= 1'b0;
      if (mult_en) begin
        if (cnt == 0) begin
          mult_shift1 <= {{(N) {1'b0}}, mult1} << 1;
          mult_shift2 <= mult2 >> 1;
          mult_acc <= mult2[0] ? {{(N) {1'b0}}, mult1} : 0;
        end else if (cnt < N) begin
          mult_shift1 <= mult_shift1 << 1;
          mult_shift2 <= mult_shift2 >> 1;
          mult_acc <= mult_acc + (mult_shift2[0] ? mult_shift1 : 0);
        end else if (cnt == N) begin
          mult_out_valid <= 1'b1;
          mult_out <= mult_acc;
        end
      end
    end
  end
endmodule
