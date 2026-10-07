module popcount#(
  parameter N =16
)
 (
   input wire [N-1:0] data_in,
   output reg [$clog2(N+1)-1:0] count
 );

 integer i;
 always@(*)begin
  count=0;
  for(i=0;i<N;i=i+1)begin
    count= count + data_in [i];
  end
 end

endmodule