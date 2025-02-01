module m_sequence_8bit (
    input wire clk,      // 时钟信号，驱动移位寄存器的移位操作
    input wire rst_n,    // 异步复位信号，低电平有效，用于初始化移位寄存器
    output m_seq     // 输出的 m 序列信号
);

    reg [7:0] shift_reg; // 定义一个 8 位的移位寄存器

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'b00000001; // 异步复位，将移位寄存器初始化为非零状态，这里选择 00000001
        end else begin
            // 根据本原多项式 x^8 + x^4 + x^3 + x^2 + 1 进行反馈操作
            shift_reg[7:1] <= shift_reg[6:0]; // 移位操作，将低 7 位依次移到高 7 位
            shift_reg[0] <= shift_reg[7] ^ shift_reg[4] ^ shift_reg[3] ^ shift_reg[2]; // 异或反馈
        end
    end

    assign m_seq = shift_reg[7]; // 取移位寄存器的最高位作为 m 序列的输出

endmodule
