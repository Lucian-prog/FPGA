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

// 50 MHz 逐样本版本。原 iir 保留供旧 TB 与数值参考使用。
// sample_en 只能在空闲时给出；上层等待 out_valid 后才接收下一帧。
// 默认对应 iir；42/42 位参数对应原 iir_ch 的乘积截断规则。
module audio_iir_step #(
  parameter STATE_W = 41,
  parameter PRODUCT_W = 57,
  parameter FEEDBACK_DIV = 1024,
  parameter OUTPUT_DIV = 8192,
  parameter signed [15:0] K1 = 1980, K2 = 959, K3 = 1026
)(
  input clk,
  input rst_n,
  input sample_en,
  input signed [15:0] din,
  output reg signed [15:0] dout,
  output reg out_valid
);
  localparam IDLE = 3'd0, MULTIPLY = 3'd1, SCALE = 3'd2,
             ADD = 3'd3, SUBTRACT = 3'd4, COMMIT = 3'd5;
  reg [2:0] state;
  reg signed [STATE_W-1:0] cache1, cache2, cache3, difference;
  reg signed [STATE_W-1:0] next_cache;
  reg signed [15:0] din_q;
  reg signed [PRODUCT_W-1:0] product1, product2, product3;
  reg signed [PRODUCT_W-1:0] feedback1, feedback2, sum;
  reg signed [15:0] result_q;
  wire signed [PRODUCT_W-1:0] scaled_output = product3 / OUTPUT_DIV;
  wire signed [PRODUCT_W-1:0] din_extended =
    {{(PRODUCT_W-16){din_q[15]}}, din_q};
  wire signed [PRODUCT_W-1:0] feedback_result = sum - feedback2;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cache1 <= 0;
      cache2 <= 0;
      cache3 <= 0;
      difference <= 0;
      next_cache <= 0;
      din_q <= 0;
      product1 <= 0;
      product2 <= 0;
      product3 <= 0;
      feedback1 <= 0;
      feedback2 <= 0;
      sum <= 0;
      result_q <= 0;
      dout <= 0;
      out_valid <= 1'b0;
    end else begin
      out_valid <= 1'b0;
      case (state)
        IDLE: if (sample_en) begin
          din_q <= din;
          difference <= cache1 - cache3;
          state <= MULTIPLY;
        end
        MULTIPLY: begin
          // 乘法与后面的缩放、加减分拍；实际映射与裕量需 STA 验证。
          product1 <= cache1 * K1;
          product2 <= cache2 * K2;
          product3 <= difference * K3;
          state <= SCALE;
        end
        SCALE: begin
          // 保留有符号除法向零截断，不能直接替换成 >>>。
          feedback1 <= product1 / FEEDBACK_DIV;
          feedback2 <= product2 / FEEDBACK_DIV;
          result_q <= scaled_output[15:0];
          state <= ADD;
        end
        ADD: begin
          sum <= din_extended + feedback1;
          state <= SUBTRACT;
        end
        SUBTRACT: begin
          // 显式保留原算法写回状态时的低位截断，不新增饱和处理。
          next_cache <= feedback_result[STATE_W-1:0];
          state <= COMMIT;
        end
        COMMIT: begin
          // 整份递推完成后再提交，期间 cache1/2/3 保持旧状态。
          cache1 <= next_cache;
          cache2 <= cache1;
          cache3 <= cache2;
          dout <= result_q;
          out_valid <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule
