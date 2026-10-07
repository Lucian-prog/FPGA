module arbit_fixed#(
   parameter N = 16
)(
   input wire clk,
   input wire rst_n,
   input wire [N-1:0] req,
   output wire [N-1:0] grant
);
    reg [N-1:0] grant_r;
    reg [N-1:0] req_prev;
    integer i;
    always@(*)begin
      if(!rst_n)begin
        req_prev=0;
        grant_r=0;
      end
      else begin
        req_prev[0]=req[0];
        grant_r[0]=req[0];
        for(i=1;i<N;i=i+1)begin
          grant_r[i]=req[i]&~req_prev[i-1];
          req_prev[i]=req[i]|req_prev[i-1];
        end
      end
    end
    assign grant=grant_r;
endmodule