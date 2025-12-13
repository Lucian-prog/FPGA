module gray_converter#
    (
        parameter N = 4
    )(
        input wire [N-1:0] bin_in,
        input wire [N-1:0] gray_in,
        output wire [N-1:0] gray_out,
        output wire [N-1:0] bin_out
    );
    assign gray_out = bin_in ^ (bin_in >> 1);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin
            if (i == N - 1)
                assign bin_out[i] = gray_in[i];
            else
                assign bin_out[i] = gray_in[i] ^ bin_out[i + 1];
        end
    endgenerate
endmodule
