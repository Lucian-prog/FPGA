// 模块: dual_port_ram（仿真版）
// 说明: 移除 clk_wiz_0 IP 依赖，用单输入时钟直接生成两个相位一致的时钟，
//       供 iverilog 仿真使用。综合时仍使用原始 Vivado 版本。
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
    input  wire [ADDR_WIDTH-1:0]   rd_addr,
    output reg  [DATA_WIDTH-1:0]   rd_data
);
    // 仿真：直接使用输入时钟（不依赖 IP）
    wire wr_clk = clk;
    wire rd_clk = clk;

    reg [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];

    // 写逻辑
    always @(posedge wr_clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    // 读逻辑
    always @(posedge rd_clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end
endmodule
