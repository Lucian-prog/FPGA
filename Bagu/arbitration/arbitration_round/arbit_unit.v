module arbit_unit#(
  parameter CH = 4
)(
  input wire [CH-1:0] req,
  input wire [CH-1:0] base,
  output wire [CH-1:0] grant
);
  wire [2*CH-1:0] req_double;
  assign req_double = {req, req};

  wire [2*CH-1:0] grant_double;
  assign grant_double = req_double & (~(req_double-base));
  assign grant = grant_double[CH-1:0] | grant_double[2*CH-1:CH];


endmodule