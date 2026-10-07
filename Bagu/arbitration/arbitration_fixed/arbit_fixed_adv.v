module arbit_fixed_adv#(
     parameter CH=16
) (
     input wire clk,
     input wire rst_n,
     input wire [CH-1:0] req,
     output wire [CH-1:0] grant
);

    assign grant= req& (~(req-1));

endmodule