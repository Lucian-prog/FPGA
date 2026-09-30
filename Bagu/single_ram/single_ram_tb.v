`timescale 1ps/1ps
module single_ram_tb;
//iverilog -o work .\single_ram_tb.v .\single_ram.v
//vvp -n .\work
//gtkwave .\single_ram_tb.vcd
  // Parameters
  parameter PERIOD = 10;
  //Ports
  reg  clk;
  reg  rst_n;
  reg [3:0] addr;
  reg [7:0] data_in;
  reg  we;
  wire [7:0] data_out;

  single_ram  single_ram_inst (
    .clk(clk),
    .rst_n(rst_n),
    .addr(addr),
    .data_in(data_in),
    .we(we),
    .data_out(data_out)
  );

//always #5  clk = ! clk ;
initial begin
  clk=0;
  forever #(PERIOD/2) clk=~clk;
end

initial begin
  rst_n=0;
  repeat(10)@(posedge clk);
  rst_n=1;
end

initial begin
  we=0;
  repeat(5)@(posedge clk);
  we=1;
  repeat(20)@(posedge clk);
  we=0;
  repeat(20)@(posedge clk);
  we=1;
  repeat(20)@(posedge clk);
  we=0;
  repeat(20)@(posedge clk);
  we=1;
  repeat(20)@(posedge clk);
  we=0;    
end

initial begin
  repeat(500)@(posedge clk);
  $finish;
end

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    addr    <= 4'd0;
    data_in <= 8'd0;
  end
  else begin
    addr    <= $random % 16;   // 0~15 随机地址
    data_in <= $random % 256;  // 0~255 随机数据
  end
end

initial begin
  $dumpfile("single_ram_tb.vcd");
  $dumpvars(0, single_ram_tb);
end

endmodule