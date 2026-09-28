module bit_sync_2ff (
  input  wire clk,
  input  wire rst_n,
  input  wire din_async,
  output reg  dout_sync,
  output wire dout_sync_valid
);

  reg sync_ff1;
  reg dout_sync_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sync_ff1    <= 1'b0;
      dout_sync   <= 1'b0;
      dout_sync_d <= 1'b0;
    end else begin
      sync_ff1    <= din_async;
      dout_sync   <= sync_ff1;
      dout_sync_d <= dout_sync;
    end
  end

  assign dout_sync_valid = dout_sync & ~dout_sync_d;

endmodule