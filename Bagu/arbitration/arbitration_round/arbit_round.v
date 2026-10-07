module arbit_round_robin #(
  parameter CH = 4
)(
  input wire clk,
  input wire rst_n,
  input wire [CH-1:0] req,
  output wire [CH-1:0] grant
);

  reg [CH-1:0] base;
  wire [CH-1:0] base_next;

  generate
    if (CH == 1) begin : gen_single_ch
      assign base_next = 1'b1;
    end
    else begin : gen_multi_ch
      assign base_next = {grant[CH-2:0], grant[CH-1]};
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      base <= {{(CH-1){1'b0}}, 1'b1};
    end
    else if (|grant) begin
      base <= base_next;
    end
    // 无请求时保持搜索起点。
  end

  arbit_unit #(
    .CH(CH)
  ) arbit_unit_inst (
    .req(req),
    .base(base),
    .grant(grant)
  );

endmodule
