`timescale 1ps/1ps
module handshake_top(
  input wire clka,
  input wire clkb,
  input wire rst_n,
  input wire [7:0] data,
  output wire [7:0] data_o
);
  
  wire req, ack;
  wire [7:0] data_tx;

  driver driver_inst(
    .clka(clka),
    .data(data),
    .rst_n(rst_n),
    .data_tx(data_tx),
    .req(req),
    .ack(ack)
  );

  receiver receiver_inst(
     .clkb(clkb),
     .data_tx(data_tx),
     .rst_n(rst_n),
     .req(req),
     .ack(ack),
     .data_o(data_o)
  );


endmodule