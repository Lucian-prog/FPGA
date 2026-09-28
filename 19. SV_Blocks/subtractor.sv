module subtractor #(parameter N=32)(
    input logic [N-1:0] a,b,
    output logic [N-1:0] y
);
    assign y = a - b;
endmodule