`timescale 1ns / 1ns

module mux2_tb();

  reg  S0, S1, S2;
  wire mux2_out;

  mux2 mux2_inst0(
    .a  (S0),
    .b  (S1),
    .sel(S2),
    .out(mux2_out)
  );

  integer err = 0;

  task check;
    input exp;
    begin
      #1;
      if (mux2_out !== exp) begin
        $display("[FAIL] sel=%b a=%b b=%b => out=%b (exp %b)", S2, S0, S1, mux2_out, exp);
        err = err + 1;
      end
    end
  endtask

  initial begin
    // sel=0 时输出 a
    S2=0; S1=0; S0=0; #10; check(0);
    S2=0; S1=0; S0=1; #10; check(1);
    S2=0; S1=1; S0=0; #10; check(0);
    S2=0; S1=1; S0=1; #10; check(1);
    // sel=1 时输出 b
    S2=1; S1=0; S0=0; #10; check(0);
    S2=1; S1=0; S0=1; #10; check(0);
    S2=1; S1=1; S0=0; #10; check(1);
    S2=1; S1=1; S0=1; #10; check(1);

    if (err == 0)
      $display("[PASS] mux2 全部8组输入验证通过");
    else
      $display("[FAIL] mux2 出错 %0d 组", err);
    $finish;
  end

  initial begin
    $dumpfile("mux2_tb.vcd");
    $dumpvars(0, mux2_tb);
  end
endmodule
