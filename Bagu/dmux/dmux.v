module dmux(
    input  wire clk_src,
    input  wire rst_n,
    input  wire valid,
    input  wire clk_dst,
    input  wire [7:0]data_in,
    output reg  [7:0]data_out
);
  reg valid_sync1, valid_sync0;
  always @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) begin
      valid_sync0 <= 0;
      valid_sync1 <= 0;
    end else begin
      valid_sync0 <= valid;
      valid_sync1 <= valid_sync0;
    end
  end

  always @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) begin
      data_out <= 8'h00;
    end else if (valid_sync1) begin
      data_out <= data_in;
    end
  end

endmodule
