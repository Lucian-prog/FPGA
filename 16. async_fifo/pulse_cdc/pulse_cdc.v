module pulse_cdc(
        input wire clk,
        input wire rst_n,
        input wire pulse_async,
        output reg pulse_sync,
        output wire pulse_sync_valid
    );
    wire pulse;

    bit_sync_2ff u_bit_sync_2ff(
                     .clk(clk),
                     .rst_n(rst_n),
                     .din_async(pulse_async),
                     .dout_sync(pulse),
                     .dout_sync_valid(pulse_sync_valid)
                 );

    pulse_stretch u_pulse_stretch(
                      .clk(clk),
                      .rst_n(rst_n),
                      .pulse(pulse),
                      .pulse_stretch(pulse_sync)
                  );
endmodule
