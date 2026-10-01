module pulse_cdc (
    input  wire clka,
    input  wire clkb,
    input  wire rst_n,
    input  wire pulse_in,
    output wire pulse_o
);
  reg [4:0] pulse_r;

  always @(posedge clka or negedge rst_n) begin
    if (!rst_n) begin
      pulse_r <= 0;
    end else begin
      pulse_r <= {pulse_r[3:0], pulse_in};
    end
  end

  wire pulse_w;
  assign pulse_w = |pulse_r;


  reg pulse_sync0, pulse_sync1, pulse_sync2;
  always @(posedge clkb or negedge rst_n) begin
    if (!rst_n) begin
      pulse_sync0 <= 0;
      pulse_sync1 <= 0;
      pulse_sync2 <= 0;
    end else begin
      pulse_sync0 <= pulse_w;
      pulse_sync1 <= pulse_sync0;
      pulse_sync2 <= pulse_sync1;
    end
  end

  assign pulse_o = pulse_sync1 & ~pulse_sync2;


endmodule
