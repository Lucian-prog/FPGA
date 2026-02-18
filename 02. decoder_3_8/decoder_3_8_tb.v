`timescale 1ns / 1ns

module decoer_3_8_tb();

  reg  A0, A1, A2;
  wire Y0, Y1, Y2, Y3, Y4, Y5, Y6, Y7;

  decoder_3_8 decoder_3_8_inst0(
    .A0(A0), .A1(A1), .A2(A2),
    .Y0(Y0), .Y1(Y1), .Y2(Y2), .Y3(Y3),
    .Y4(Y4), .Y5(Y5), .Y6(Y6), .Y7(Y7)
  );

  wire [7:0] Y = {Y7,Y6,Y5,Y4,Y3,Y2,Y1,Y0};
  integer err = 0;
  integer i;

  task check;
    input [2:0] code;
    input [7:0] exp;
    begin
      {A2,A1,A0} = code; #10;
      if (Y !== exp) begin
        $display("[FAIL] A=%b => Y=%b (exp %b)", code, Y, exp);
        err = err + 1;
      end
    end
  endtask

  initial begin
    check(3'd0, 8'b0000_0001);
    check(3'd1, 8'b0000_0010);
    check(3'd2, 8'b0000_0100);
    check(3'd3, 8'b0000_1000);
    check(3'd4, 8'b0001_0000);
    check(3'd5, 8'b0010_0000);
    check(3'd6, 8'b0100_0000);
    check(3'd7, 8'b1000_0000);

    if (err == 0)
      $display("[PASS] decoder_3_8 全部8组验证通过");
    else
      $display("[FAIL] decoder_3_8 出错 %0d 组", err);
    $finish;
  end

  initial begin
    $dumpfile("decoder_3_8_tb.vcd");
    $dumpvars(0, decoer_3_8_tb);
  end
endmodule
