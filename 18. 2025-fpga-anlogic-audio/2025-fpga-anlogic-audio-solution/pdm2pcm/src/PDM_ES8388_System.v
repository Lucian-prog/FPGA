
module PDM_ES8388_System(
    // 系统时钟和复位
    input clk,                    // 50MHz系统时钟
    input rst_n,                // 异步复位，低电平有效

    // PDM接口 - 双麦克风共用数据线
    output wire pdm_sck,          // PDM时钟输出 (同时作为L/R选择信号)
    input wire  pdm_dat1,
    input wire  pdm_dat2,
    input wire  pdm_dat3,
    input wire  pdm_dat4,          // PDM数据输入 (左右声道共用)
    input wire key1,
    input wire key2,
    input wire key3,
    input wire key4,
    // ES8388 I2C接口
    inout iic_0_scl,              // I2C时钟线
    inout iic_0_sda,              // I2C数据线

    // ES8388 I2S接口（仅DAC，移除ADC）
    output I2S_RCLK,              // I2S帧时钟（LRCK）
    output I2S_BCLK,              // I2S位时钟
    output I2S_DO,                // I2S数据输出到DAC
    output I2S_MCLK              // I2S主时钟

  );

  parameter DATA_WIDTH = 32;    // I2S数据宽度（左右声道各16位）
  // PDM转PCM相关信号
  wire clk_48mhz;              // 48MHz时钟（用于PDM处理）
  wire signed [15:0] pcm_data_l;      // PCM数据 - 左声道
  wire signed [15:0] pcm_data_r;      // PCM数据 - 右声道
  wire pcm_valid;              // PCM数据有效

  // ES8388初始化相关
  wire Init_Done;              // ES8388初始化完成

  // DAC FIFO相关信号
  reg dacfifo_write;
  reg signed[DATA_WIDTH-1:0] dacfifo_writedata;
  wire dacfifo_full;

  //--------------------------------------------------------------
  // PLL时钟生成
  //--------------------------------------------------------------
  // 主PLL：50MHz -> 12.288MHz (MCLK)
  pll pll_inst (
        .refclk      (clk),
        .reset      (~rst_n),
        .clk0_out    (),
        .clk1_out    (clk_48mhz),
        .clk2_out    (I2S_MCLK),
        .extlock       ()              // 连接锁定信号
      );

  clkdiv #(
           .WIDTH              (3),                // 至少需要3位表示4
           .N                  (4)                 // 4分频: 12.288MHz / 4 = 3.072MHz
         ) I2S_BCLK_div (
           .clk                (I2S_MCLK),
           .rst_n              (rst_n),
           .clkout             (I2S_BCLK)
         );

  // 生成 LRCK (48 kHz)
  clkdiv #(
           .WIDTH              (8),                // 至少需要8位表示256
           .N                  (256)               // 256分频: 12.288MHz / 256 = 48kHz
         ) es8388_lrck_div (
           .clk                (I2S_MCLK),
           .rst_n              (rst_n),
           .clkout             (I2S_RCLK)
         );



  //--------------------------------------------------------------
  // ES8388初始化模块
  //--------------------------------------------------------------
  ES8388_Init ES8388_Init_inst(
                .Clk(clk),
                .Rst_n(rst_n),
                .I2C_Init_Done(Init_Done),
                .i2c_sclk(iic_0_scl),
                .i2c_sdat(iic_0_sda)
              );

  wire key_press1, key_press2, key_press3, key_press4;
  key_filter key_mode_filter1 (
                .clk            (clk),
                .rst_n          (rst_n),
                .key            (key1),         // 按键输入（低电平有效）
                .key_p_flag     (key_press1),        // 按键按下脉冲（单周期）
                .key_r_flag     (),      // 按键释放脉冲（单周期）
                .key_state      ()     // 按键状态：1=释放，0=按下
              );
  key_filter key_mode_filter2 (
                .clk            (clk),
                .rst_n          (rst_n),
                .key            (key2),         // 按键输入（低电平有效）
                .key_p_flag     (key_press2),        // 按键按下脉冲（单周期）
                .key_r_flag     (),      // 按键释放脉冲（单周期）
                .key_state      ()     // 按键状态：1=释放，0=按下
              );
  key_filter key_mode_filter3 (
                .clk            (clk),
                .rst_n          (rst_n),
                .key            (key3),         // 按键输入（低电平有效）
                .key_p_flag     (key_press3),        // 按键按下脉冲（单周期）
                .key_r_flag     (),      // 按键释放脉冲（单周期）
                .key_state      ()     // 按键状态：1=释放，0=按下
              );
  key_filter key_mode_filter4 (
                .clk            (clk),
                .rst_n          (rst_n),
                .key            (key4),         // 按键输入（低电平有效）
                .key_p_flag     (key_press4),        // 按键按下脉冲（单周期）
                .key_r_flag     (),      // 按键释放脉冲（单周期）
                .key_state      ()     // 按键状态：1=释放，0=按下
              );
  reg [2:0] state; // 状态寄存器，0-4表示不同的麦克风通道
  
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state <= 3'd1;  // 初始状态为1，选择第一个麦克风
    end
    else
    begin
      // 按键切换逻辑：每个按键对应一个固定的麦克风通道
      if (key_press1)
      begin
        state <= 3'd1;  // 切换到麦克风1
      end
      else if (key_press2)
      begin
        state <= 3'd2;  // 切换到麦克风2
      end
      else if (key_press3)
      begin
        state <= 3'd3;  // 切换到麦克风3
      end
      else if (key_press4)
      begin
        state <= 3'd4;  // 切换到麦克风4
      end
    end
  end
  
  // 根据state选择对应的麦克风数据
  wire pdm_dat_ch;
  assign pdm_dat_ch = (state == 3'd1) ? pdm_dat1 :
                      (state == 3'd2) ? pdm_dat2 :
                      (state == 3'd3) ? pdm_dat3 :
                      (state == 3'd4) ? pdm_dat4 : pdm_dat1;  // 默认选择麦克风1
  // 选择一个PDM数据线作为输入（假设共用数据线）
  //--------------------------------------------------------------
  // PDM到PCM转换模块 - 双声道（共用数据线）
  //--------------------------------------------------------------
  pdm_to_pcm #(
               .SYS_CLK_FREQ(48_000_000),  // 使用48MHz时钟
               .FS_IN(2_400_000),          // 2.4MHz PDM采样率
               .M(5),                      // CIC滤波器级数
               .R(50),                     // 抽取比（2.4MHz / 50 = 48kHz）
               .DW(16),                    // PCM数据位宽
               .SCALE_FACTOR(6000)         // CIC输出缩放因子
             ) pdm_pcm_inst (
               .clk(clk_48mhz),           // 使用48MHz时钟域
               .rst_n(rst_n),             // 使用同步复位
               .ena(1),           // ES8388初始化完成后才开始处理

               .pdm_clk(pdm_sck),         // PDM时钟，同时作为L/R选择
               .pdm_dat(pdm_dat_ch),         // 左右声道共用数据线

               .pcm_data_l(pcm_data_l),   // 左声道PCM输出
               .pcm_data_r(pcm_data_r),   // 右声道PCM输出
               .pcm_valid(pcm_valid)
             );
   
    
   

  //--------------------------------------------------------------
  // PCM数据到DAC FIFO的转换 - 左右声道分别输出
  // 关键修复：在48MHz时钟域直接写入FIFO，避免跨时钟域数据损坏
  //--------------------------------------------------------------
  always @(posedge clk_48mhz or negedge rst_n)
  begin
    if(~rst_n)
    begin
      dacfifo_write <= 1'd0;
      dacfifo_writedata <= 32'd0;
    end
    else if(pcm_valid && ~dacfifo_full && Init_Done)
    begin
      dacfifo_write <= 1'd1;
      if(state ==3'd1 | state == 3'd2 | state == 3'd3)begin
      // 将左右声道16位PCM数据组合为32位立体声数据（已在pdm2pcm模块内完成IIR滤波）
      dacfifo_writedata <= {pcm_data_l, pcm_data_r};
      end
      else if(state ==3'd4) begin
        // 第四个麦克风只输出单声道数据到左声道，右声道静音
        dacfifo_writedata <= {16'd0, pcm_data_r};
      end
    end
    else
    begin
      dacfifo_write <= 1'd0;
    end
  end

  // I2S发送模块（仅DAC输出）
  //--------------------------------------------------------------
  i2s_tx #(
           .DATA_WIDTH(DATA_WIDTH)
         ) i2s_tx_inst (
           .rst_n(rst_n),
           .dacfifo_wrclk(clk_48mhz),
           .dacfifo_wren(dacfifo_write),
           .dacfifo_wrdata(dacfifo_writedata),
           .dacfifo_full(dacfifo_full),
           .bclk(I2S_BCLK),
           .daclrc(I2S_RCLK),
           .dacdat(I2S_DO)
         );

endmodule
