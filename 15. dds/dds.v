module dds(
    input clk, //48khz
    input rst_n,
    input [9:0]dds_freq, //48hz/div
    output reg signed [15:0]ddso
  );

  reg signed [15:0]sin_rom[0:1023];

  integer i;

  initial
  begin
    for(i=0;i<1024;i=i+1)
    begin
      sin_rom[i] = 32700 * $sin(2*3.14159*i/1024);
    end
  end

  reg [9:0]addr;

  always@(posedge clk or negedge rst_n)
  begin
    if(!rst_n)
    begin
      addr <= 0;
      ddso <= 0;
    end
    else
    begin
      addr <= addr + dds_freq;
      ddso <= sin_rom[addr];
    end
  end

endmodule
