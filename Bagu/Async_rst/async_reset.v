module async_reset(
    input wire clk,
    input wire rst_n,
    output wire rst_out
);
    reg rst_sync0,rst_sync1;

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            rst_sync0 <=0;
            rst_sync1 <=0;
        end
        else begin
            rst_sync0 <=1;
            rst_sync1 <=rst_sync0;
        end
    end
    assign rst_out = rst_sync1;
endmodule