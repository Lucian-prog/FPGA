
module gray_converter_tb;

    localparam  N = 4;

    reg [N-1:0] bin_in;
    reg [N-1:0] gray_in;
    wire [N-1:0] gray_out;
    wire [N-1:0] bin_out;

    gray_converter # (
                       .N(N)
                   )
                   gray_converter_inst (
                       .bin_in(bin_in),
                       .gray_in(gray_in),
                       .gray_out(gray_out),
                       .bin_out(bin_out)
                   );

    //always #5  clk = ! clk ;
    initial begin
        $dumpfile("tb_gray_converter.vcd");
        $dumpvars(0, gray_converter_tb);
        bin_in = 0;
        gray_in=0;
        #10;
        bin_in=4'b0000;
        gray_in=4'b0000;
        #10;
        bin_in=4'b0001;
        gray_in=4'b0001;
        #10;
        bin_in=4'b0010;
        gray_in=4'b0011;
        #10;
        bin_in=4'b0011;
        gray_in=4'b0010;
        #10;
        bin_in=4'b0100;
        gray_in=4'b0110;
        #10;
        bin_in=4'b0101;
        gray_in=4'b0111;
        #10;
        bin_in=4'b0110;
        gray_in=4'b0101;
        #10;
        bin_in=4'b0111;
        gray_in=4'b0100;
        #10;
        bin_in=4'b1000;
        gray_in=4'b1100;
        #10;
        bin_in=4'b1001;
        gray_in=4'b1101;
        #10;
        bin_in=4'b1010;
        gray_in=4'b1111;
        #10;
        bin_in=4'b1011;
        gray_in=4'b1110;
        #10;
        bin_in=4'b1100;
        gray_in=4'b1010;
        #10;
        bin_in=4'b1101;
        gray_in=4'b1011;
        #10;
        bin_in=4'b1110;
        gray_in=4'b1001;
        #10;
        bin_in=4'b1111;
        gray_in=4'b1000;
        #10;
        $finish;
    end
endmodule
