`timescale 1ns/1ps

module top_tb;

    //--------------------------------------------------------------
    // 信号定义
    //--------------------------------------------------------------
    reg clk;                    // 50MHz系统时钟
    reg rst_n;                  // 复位信号
    
    // PDM接口
    wire pdm_sck;               // PDM时钟输出
    reg  pdm_dat;               // PDM数据输入
    
    // I2C接口
    wire iic_0_scl;
    wire iic_0_sda;
    
    // I2S接口
    wire I2S_RCLK;              // LRCK
    wire I2S_BCLK;              // BCLK
    wire I2S_DO;                // DAC数据输出
    wire I2S_MCLK;              // MCLK

    //--------------------------------------------------------------
    // 时钟生成：50MHz (周期20ns)
    //--------------------------------------------------------------
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50MHz时钟
    end

    //--------------------------------------------------------------
    // 复位序列
    //--------------------------------------------------------------
    initial begin
        rst_n = 0;
        #100;                    // 复位保持100ns
        rst_n = 1;
        $display("Reset released at time %t", $time);
    end

    //--------------------------------------------------------------
    // PDM数据生成 - 模拟1kHz正弦波的PDM编码
    // 简化版：生成密度调制的位流
    //--------------------------------------------------------------
    reg [15:0] pdm_counter;
    reg [7:0] sine_index;
    reg [7:0] sine_value;
    
    // 简单的正弦波查找表 (8个采样点)
    always @(*) begin
        case(sine_index[2:0])
            3'd0: sine_value = 128;  // 0度
            3'd1: sine_value = 218;  // 45度
            3'd2: sine_value = 255;  // 90度
            3'd3: sine_value = 218;  // 135度
            3'd4: sine_value = 128;  // 180度
            3'd5: sine_value = 38;   // 225度
            3'd6: sine_value = 0;    // 270度
            3'd7: sine_value = 38;   // 315度
            default: sine_value = 128;
        endcase
    end

    // PDM数据生成逻辑
    always @(posedge pdm_sck or negedge rst_n) begin
        if (!rst_n) begin
            pdm_counter <= 0;
            sine_index <= 0;
            pdm_dat <= 0;
        end else begin
            // 每256个PDM时钟更新一次正弦波采样点
            if (pdm_counter == 255) begin
                pdm_counter <= 0;
                sine_index <= sine_index + 1;
            end else begin
                pdm_counter <= pdm_counter + 1;
            end
            
            // 简单的一阶Sigma-Delta调制
            // 比较正弦波值和计数器，生成PDM位流
            pdm_dat <= (sine_value > pdm_counter[7:0]) ? 1'b1 : 1'b0;
        end
    end

    //--------------------------------------------------------------
    // I2C从设备模拟 (简化版 - 自动应答)
    //--------------------------------------------------------------
    pullup(iic_0_scl);
    pullup(iic_0_sda);

    //--------------------------------------------------------------
    // 被测模块实例化
    //--------------------------------------------------------------
    PDM_ES8388_System dut (
        .clk(clk),
        .rst_n(rst_n),
        
        .pdm_sck(pdm_sck),
        .pdm_dat(pdm_dat),
        
        .iic_0_scl(iic_0_scl),
        .iic_0_sda(iic_0_sda),
        
        .I2S_RCLK(I2S_RCLK),
        .I2S_BCLK(I2S_BCLK),
        .I2S_DO(I2S_DO),
        .I2S_MCLK(I2S_MCLK)
    );

    //--------------------------------------------------------------
    // 监控和显示
    //--------------------------------------------------------------
    // 监控PCM数据输出
    integer pcm_count;
    initial begin
        pcm_count = 0;
    end

    always @(posedge I2S_RCLK) begin
        if (rst_n) begin
            pcm_count = pcm_count + 1;
            if (pcm_count % 100 == 0) begin
                $display("Time=%t: PCM frame #%d, LRCK=%b, BCLK=%b", 
                         $time, pcm_count, I2S_RCLK, I2S_BCLK);
            end
        end
    end

    // 监控PDM时钟
    real pdm_freq;
    time pdm_period_start, pdm_period_end;
    initial begin
        @(posedge rst_n);
        @(posedge pdm_sck);
        pdm_period_start = $time;
        @(posedge pdm_sck);
        pdm_period_end = $time;
        pdm_freq = 1000000000.0 / (pdm_period_end - pdm_period_start);
        $display("PDM Clock Frequency: %.2f MHz", pdm_freq / 1000000.0);
    end

    // 监控I2S LRCK频率
    real lrck_freq;
    time lrck_period_start, lrck_period_end;
    initial begin
        @(posedge rst_n);
        repeat(10) @(posedge clk); // 等待稳定
        @(posedge I2S_RCLK);
        lrck_period_start = $time;
        @(posedge I2S_RCLK);
        lrck_period_end = $time;
        lrck_freq = 1000000000.0 / (lrck_period_end - lrck_period_start);
        $display("I2S LRCK Frequency: %.2f kHz", lrck_freq / 1000.0);
    end

    //--------------------------------------------------------------
    // 波形文件生成
    //--------------------------------------------------------------
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
    end

    //--------------------------------------------------------------
    // 仿真控制
    //--------------------------------------------------------------
    initial begin
        $display("========================================");
        $display("PDM to ES8388 System Testbench");
        $display("========================================");
        
        // 运行足够长的时间以观察多个PCM采样
        #20_000_000;  // 20ms仿真时间
        
        $display("========================================");
        $display("Simulation completed at time %t", $time);
        $display("Total PCM frames: %d", pcm_count);
        $display("========================================");
        $finish;
    end

    //--------------------------------------------------------------
    // 超时保护
    //--------------------------------------------------------------
    initial begin
        #50_000_000;  // 50ms超时
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
