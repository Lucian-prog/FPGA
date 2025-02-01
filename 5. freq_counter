module freq_counter(
    input  wire clk,        // 系统时钟 50MHz
    input  wire reset,
    input  wire B,          // PLL 输出时钟 B
    output reg [31:0] freq_out  // 计算出的频率（Hz）
);
    parameter WINDOW = 5000000;  // 测量窗口长度（100ms）
    reg [31:0] count;
    reg [31:0] window_cnt;
    reg B_sync, B_sync_prev;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count        <= 0;
            window_cnt   <= 0;
            freq_out     <= 0;
            B_sync       <= 0;
            B_sync_prev  <= 0;
        end else begin
            // 对 B 信号进行两级同步
            B_sync      <= B;
            B_sync_prev <= B_sync;
            if (window_cnt < WINDOW - 1) begin
                window_cnt <= window_cnt + 1;
                if (B_sync & ~B_sync_prev) begin
                    count <= count + 1;
                end
            end else begin
                // 计算频率：count * (50e6 / WINDOW) = count * 10
                freq_out <= count * 10;
                window_cnt <= 0;
                count <= 0;
            end
        end
    end
endmodule
