module nco(
    input  wire clk,
    input  wire reset,
    input  wire [15:0] freq_control,
    output reg  B   // 输出的 PLL 时钟 B
);
    reg [31:0] phase_acc;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            phase_acc <= 0;
            B         <= 0;
        end else begin
            // 将控制字扩展至32位后加到相位累加器
            phase_acc <= phase_acc + {16'b0, freq_control};
            // 取 MSB 作为输出时钟
            B <= phase_acc[31];
        end
    end
endmodule
