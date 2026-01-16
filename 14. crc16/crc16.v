`timescale 1ns / 1ps
module crc16 #(
  parameter [15:0] POLY = 16'h1021,
  parameter [15:0] INIT = 16'hFFFF,
  parameter REFLECT_IN = 1'b0,
  parameter REFLECT_OUT = 1'b0,
  parameter [15:0] XOR_OUT = 16'h0000
) (
  input wire clk,
  input wire rst_n,
  input wire clear,
  input wire [7:0] data_in,
  input wire data_valid,
  output wire [15:0] crc_out
);
  reg [15:0] crc_reg;
  reg [15:0] crc_next;
  reg [7:0] data_reflected;
  reg [15:0] poly_reflected;
  reg [15:0] crc_out_reg;
  integer i;
  integer j;

  always @* begin
    data_reflected = data_in;
    poly_reflected = POLY;
    if (REFLECT_IN) begin
      for (i = 0; i < 8; i = i + 1) begin
        data_reflected[i] = data_in[7 - i];
      end
      for (i = 0; i < 16; i = i + 1) begin
        poly_reflected[i] = POLY[15 - i];
      end
    end
    crc_next = crc_reg;
    if (REFLECT_IN) begin
      crc_next = crc_next ^ {8'h00, data_reflected};
      for (i = 0; i < 8; i = i + 1) begin
        if (crc_next[0]) begin
          crc_next = (crc_next >> 1) ^ poly_reflected;
        end else begin
          crc_next = crc_next >> 1;
        end
      end
    end else begin
      crc_next = crc_next ^ {data_reflected, 8'h00};
      for (i = 0; i < 8; i = i + 1) begin
        if (crc_next[15]) begin
          crc_next = (crc_next << 1) ^ POLY;
        end else begin
          crc_next = crc_next << 1;
        end
      end
    end
  end

  always @* begin
    crc_out_reg = crc_reg;
    if (REFLECT_OUT) begin
      for (j = 0; j < 16; j = j + 1) begin
        crc_out_reg[j] = crc_reg[15 - j];
      end
    end
    crc_out_reg = crc_out_reg ^ XOR_OUT;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      crc_reg <= INIT;
    end else if (clear) begin
      crc_reg <= INIT;
    end else if (data_valid) begin
      crc_reg <= crc_next;
    end
  end

  assign crc_out = crc_out_reg;
endmodule
