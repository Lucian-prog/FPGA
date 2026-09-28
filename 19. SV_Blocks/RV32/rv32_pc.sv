module rv32_pc (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] pc_next_i,
  output logic [31:0] pc_o
);
      always_ff @(posedge clk or negedge rst_n) begin
          if(!rst_n) begin
              pc_o<=0;
          end
          else begin
              pc_o<=pc_next_i;
          end
      end

endmodule