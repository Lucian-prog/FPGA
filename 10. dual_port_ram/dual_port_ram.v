module dual_port_ram #(
        parameter DATA_WIDTH = 8,
        parameter ADDR_WIDTH = 4   // 深度 = 2^4 = 16
    )(
        // 写端口
        input  wire                    clk,
        input  wire                    resetn,

        input  wire [ADDR_WIDTH-1:0]   wr_addr,
        input  wire [DATA_WIDTH-1:0]   wr_data,
        input  wire                    wr_en,
        // 读端口
        input  wire                    rd_en,
        input  wire [ADDR_WIDTH- 1:0]   rd_addr,
        output reg  [DATA_WIDTH-1:0]   rd_data
    );
    wire wr_clk;
    wire rd_clk;
    clk_wiz_0 PLL(
                  // Clock out ports
                  .clk_out1(wr_clk),
                  .clk_out2(rd_clk),
                  // Status and control signals
                  .resetn(resetn),
                  // Clock in ports
                  .clk_in1(clk)
              );

    reg [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];
    //写逻辑
    always @(posedge wr_clk) begin
        if(wr_en)
            mem[wr_addr] <= wr_data;
    end
    // 读逻辑
    always @(posedge rd_clk) begin
        if(rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end
endmodule
