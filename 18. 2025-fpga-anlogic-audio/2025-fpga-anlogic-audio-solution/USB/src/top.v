//================================================================================
// 文件名    : top.v
// 平台      : 安路EG4S20BG256 FPGA
// 时钟      : 50MHz板载晶振
// 功能      : USB音频录音 + ES8388本地监听 + 声源定位
// 应用场景  : EQ增强模式+通话
// 版本      : V2.0
// 日期      : 2025-11-26
//================================================================================

module top (
    input  wire         clk50mhz,           // 50MHz板载晶振
    input  wire         rst_n,              // 低电平复位

    input  wire         mode_switch,        // 模式切换按钮: 0=普通模式, 1=声源定位模式

    // ========== 麦克风接口 (I2S) ==========
    output wire         mic_clk,            // 麦克风时钟 (~3MHz)
    output wire         mic_ws,             // 麦克风帧时钟
    input  wire [3:0]   mic_data,           // 4路麦克风数据输入
    input  wire         sw0, 
    input  wire         sw1,                //窄带通话开关
    input  wire         sw2,                //低音增强EQ开关
    input  wire         sw3,                //人声增强EQ开关
    input  wire         sw4,                //氛围感增强EQ开关
    input  wire         sw5,                //AEC开关
    // ========== USB接口 ==========
    output wire         usb_dp_pull,        // USB D+ 上拉使能
    inout               usb_dp,             // USB D+
    inout               usb_dn,             // USB D-

    // ========== ES8388接口 ==========
    // ES8388 I2C接口
    inout iic_0_scl,              // I2C时钟线
    inout iic_0_sda,              // I2C数据线

    // ES8388 I2S接口（仅DAC，移除ADC）
    output I2S_RCLK,              // I2S帧时钟（LRCK）
    output I2S_BCLK,              // I2S位时钟
    output I2S_DO,                // I2S数据输出到DAC
    output I2S_MCLK,              // I2S主时钟



    // ========== SK9822 LED ==========
    output wire         sk9822_clk,         // SK9822时钟
    output wire         sk9822_data,      // SK9822数据

    output wire         uart_tx             // USB调试串口输出
  );

  wire clk60mhz;                  // 60MHz USB/DSP时钟
  wire clk_slow;                 // 降频后的时钟（约1MHz）
  // 复位信号
  wire finished_temp1;
  wire rst_dsp= rst_n&(!finished_temp1); // xcorr模块复位信号
  wire usb_rstn;                  // USB复位

  //================================================================================
  // 工作模式状态机
  //================================================================================
  // 0: NORMAL_MODE    - 普通USB音频录音模式，LED关闭
  // 1: LOCALIZATION_MODE - 声源定位模式，LED显示方向
  reg work_mode;
  reg mode_switch_d1, mode_switch_d2;  // 按钮消抖
  wire mode_switch_pulse;

  // 按钮消抖和边沿检测
  always @(posedge clk50mhz or negedge rst_n)
  begin
    if (!rst_n)
    begin
      mode_switch_d1 <= 1'b0;
      mode_switch_d2 <= 1'b0;
    end
    else
    begin
      mode_switch_d1 <= mode_switch;
      mode_switch_d2 <= mode_switch_d1;
    end
  end

  assign mode_switch_pulse = mode_switch_d1 & ~mode_switch_d2;  // 上升沿


  always @(posedge clk50mhz or negedge rst_n)
  begin
    if (!rst_n)
    begin
      work_mode <= 1'b0;
    end
    else if (mode_switch_pulse)
    begin
      work_mode <= ~work_mode;
    end
  end

  // 麦克风数据 (24位)
  wire signed [23:0] mic_0, mic_1, mic_2, mic_3, mic_4, mic_5,mic_6;
  wire mic_finished_left, mic_finished_right;
  wire mic_start;

  reg  es8388_data_valid;         // ES8388 数据有效信号（持续有效）

  // USB音频数据
  wire        audio_en;           // 48kHz采样脉冲
  wire        audio_en_total;     // 扩展采样脉冲
  wire [10:0] cnt;                // USB内部计数器

  // 声源定位
  wire [5:0] sequence1, sequence2, sequence3;  // 修改为6位宽度

  // 调试信号
  wire        debug_en;
  wire [7:0]  debug_data;
  // ES8388初始化相关
  wire Init_Done;              // ES8388初始化完成

  // DAC FIFO相关信号
  reg dacfifo_write;
  reg [31:0] dacfifo_writedata;
  wire dacfifo_full;

  // I2S时钟相关
  reg[10:0] lrclk_cnt;
  reg i2s_lrck;
  //================================================================================
  // 时钟与复位管理
  //================================================================================

  // PLL #1: 50MHz → 60MHz (USB/DSP时钟)
  // PLL #2: 50MHz → 12.288MHz (ES8388 MCLK)

  pll pll_inst (
        .refclk      (clk50mhz),
        .reset      (~rst_n),
        .clk0_out    (),
        .clk1_out    (clk60mhz),
        .clk2_out    (I2S_MCLK),
        .extlock       ()              // 连接锁定信号
      );

  assign es8388_mclk = I2S_MCLK;

  //================================================================================
  // ES8388 I2S时钟生成（从 MCLK 分频）
  //================================================================================
  // MCLK = 12.288 MHz
  // SCLK = 3.072 MHz (12.288 / 4 = 3.072)  → 48kHz * 64 bit
  // LRCK = 48 kHz (12.288M / 256 = 48k)

  // 生成 SCLK (3.072 MHz)
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

  clkdiv #(
           .WIDTH              (16),               // 至少需要16位表示50000
           .N                  (50)             // 50,000分频: 50MHz / 50 = 1MHz
         ) clk_slow_div (
           .clk                (clk50mhz),
           .rst_n              (rst_n),
           .clkout             (clk_slow)
         );
  
         
  //================================================================================
  // 麦克风采集模块 (6路I2S)
  //================================================================================

  mic_serial mic_serial_inst (
               .clk                (clk50mhz),
               .rst_n              (rst_n),
               .rst_dsp            (rst_dsp ),
               .mic_clk            (mic_clk),          // 连接到顶层输出
               .mic_ws             (mic_ws),
               .mic_so             (mic_data),
               .mic_0              (mic_0),
               .mic_1              (mic_1),
               .mic_2              (mic_2),
               .mic_3              (mic_3),
               .mic_4              (mic_4),
               .mic_5              (mic_5),
               .mic_6              (mic_6),
               .finished_left1     (mic_finished_left),
               .finished_right1    (mic_finished_right),
               .start              (mic_start)
             );

  //================================================================================
  // ES8388 数据有效信号生成 - 仅在普通模式下有效
  //================================================================================
  // 说明：mic_finished_left 是脉冲信号，在 i2s_bclk 域容易错过
  //       这里生成一个持续有效的信号，在麦克风启动后始终为高
  //       在声源定位模式下，关闭ES8388输出
  always @(posedge clk50mhz or negedge rst_n)
  begin
    if (!rst_n)
    begin
      es8388_data_valid <= 1'b0;
    end
    else
    begin
      if (work_mode)
      begin
        // 声源定位模式：关闭ES8388
        es8388_data_valid <= 1'b0;
      end
      else if (mic_start)
      begin
        // 普通模式：麦克风启动后，数据持续有效
        es8388_data_valid <= 1'b1;
      end
    end
  end


  //================================================================================
  // 声源定位 (互相关计算 × 3) - 仅在声源定位模式下工作
  //================================================================================
  wire finished;
  wire xcorr_enable;
  assign xcorr_enable = work_mode;  // 1=定位模式时使能xcorr

  xcorr xcorr1 (
          .clk                (clk50mhz),
          .rst_n              (rst_dsp & xcorr_enable),  // 普通模式下保持复位
          .start_flag         (mic_start & xcorr_enable),
          .finish_left        (mic_finished_left),
          .finish_right       (mic_finished_right),
          .mic_1              (mic_2[23:6]),      // 使用高18位
          .mic_2              (mic_5[23:6]),      // 使用高18位
          .sequence_num       (sequence1),
          .finished           (finished),                 // 未使用
          .finished_temp1     (finished_temp1)                  // 未使用
        );

  xcorr xcorr2 (
          .clk                (clk50mhz),
          .rst_n              (rst_dsp & xcorr_enable),
          .start_flag         (mic_start & xcorr_enable),
          .finish_left        (mic_finished_left),
          .finish_right       (mic_finished_right),
          .mic_1              (mic_0[23:6]),      // 使用高18位
          .mic_2              (mic_3[23:6]),      // 使用高18位
          .sequence_num       (sequence2),
          .finished           (),                 // 未使用
          .finished_temp1     ()                  // 未使用
        );

  xcorr xcorr3 (
          .clk                (clk50mhz),
          .rst_n              (rst_dsp & xcorr_enable),
          .start_flag         (mic_start & xcorr_enable),
          .finish_left        (mic_finished_left),
          .finish_right       (mic_finished_right),
          .mic_1              (mic_1[23:6]),      // 使用高18位
          .mic_2              (mic_4[23:6]),      // 使用高18位
          .sequence_num       (sequence3),
          .finished           (),                 // 未使用
          .finished_temp1     ()                  // 未使用
        );

  //================================================================================
  // SK9822 LED驱动 (声源方向指示) - 仅在声源定位模式下工作
  //================================================================================

  mic_led sk9822_dir (
            .clk_slow                (clk_slow),
            .rst_n              (rst_n),
            .mic1               (work_mode ? sequence1 : 6'd0),  // 普通模式时输出0
            .mic2               (work_mode ? sequence2 : 6'd0),
            .mic3               (work_mode ? sequence3 : 6'd0),
            .tVAD               (work_mode),        // 普通模式下关闭LED
            .sk9822_ck          (sk9822_clk),
            .sk9822_da          (sk9822_data),
            .direction          (),                 // 未使用
            .direction2         (),                 // 未使用
            .direction3         ()                  // 未使用
          );

  wire tVAD;
  wire signed [15:0] audio_l_process;
  wire signed [15:0] audio_r_process;
 
  AUDIO_PROCESS audio_lite(
                  .rst_n(rst_n),
                  .sw0(sw0),
                  .sw1(sw1),
                  .sw2(sw2),
                  .sw3(sw3),
                  .sw4(sw4),
                  .sw5(sw5),
                  .audio_r(mic_0[23:8]),
                  .audio_l(mic_1[23:8]),
                  .audio_ref(16'd13000),
                  .data_async(I2S_RCLK),
                  .o_audio_r(audio_r_process),
                  .o_audio_l(audio_l_process),
                  .tVAD(tVAD)
                );
  //================================================================================
  // USB音频控制器 - 仅在普通模式下工作
  //================================================================================
  assign audio_li = mic_1[23:8];
  assign audio_ri = mic_0[23:8];
  wire data_async;
  wire [10:0] audio_1250_cnt;
  wire data_valid;
  // USB使能控制：仅在普通模式(work_mode=0)下工作
  wire usb_enable;
  assign usb_enable = ~work_mode;
  usb_audio_top #(
                  .DEBUG           ( "FALSE"             )    // If you want to see the debug info of USB device core, set this parameter to "TRUE"
                ) u_usb_audio (
                  .rstn            ( rst_n ),     // 声源定位模式下保持复位
                  .clk             ( clk60mhz            ),
                  // USB signals
                  .usb_dp_pull    (usb_dp_pull ),  // 声源定位模式下禁用上拉
                  .usb_dp          ( usb_dp              ),
                  .usb_dn          ( usb_dn              ),
                  // USB reset output
                  .usb_rstn        ( usb_rstn            ),   // 1: connected , 0: disconnected (when USB cable unplug, or when system reset (rstn=0))
                  // user data : audio output (host-to-device, such as a speaker), and audio input (device-to-host, such as a microphone).
                  .audio_en        (   data_async               ),
                  // .audio_lo        (  audio_lo            ),   // left-channel output : 16-bit signed integer, which will be valid when audio_en=1
                  //  .audio_ro        (  audio_ro            ),   // right-channel output: 16-bit signed integer, which will be valid when audio_en=1
                  .audio_li        (   audio_l_process ),   // left-channel input  : 16-bit signed integer, which will be sampled when audio_en=1
                  .audio_ri        (   audio_r_process ),   // right-channel input : 16-bit signed integer, which will be sampled when audio_en=1
                  // debug output info, only for USB developers, can be ignored for normally use
                  .debug_en        (                     ),
                  .debug_data      (                     ),
                  .debug_uart_tx   ( uart_tx             ),
   
                  .audio_en_total    (    data_valid   ),
                  .cnt                 ( audio_1250_cnt  )
                );


  //================================================================================

  //================================================================================
  // ES8388音频编解码器 - 仅在普通模式下工作
  //================================================================================
  wire signed [15:0] audio_l_es8388;
  wire signed [15:0] audio_r_es8388;
  assign audio_l_es8388 = audio_l_process;
  assign audio_r_es8388 =  audio_r_process; 
  always @ (posedge clk50mhz or negedge rst_n)
  begin
    if(~rst_n)
    begin
      dacfifo_write <= 1'd0;
      dacfifo_writedata <= 32'd0;
    end
    else if( es8388_data_valid && ~dacfifo_full && Init_Done && ~work_mode)
    begin
      // 仅在普通模式(work_mode=0)下写入FIFO
      dacfifo_write <= 1'd1;
      // 将16位PCM数据扩展为32位立体声数据（左右声道相同）
      dacfifo_writedata <= {audio_l_es8388, audio_r_es8388};
    end
    else
      
    begin
      dacfifo_write <= 1'd0;
    end
  end
  // ES8388初始化模块
  ES8388_Init ES8388_Init_inst(
                .Clk(clk50mhz),
                .Rst_n(rst_n),
                .I2C_Init_Done(Init_Done),
                .i2c_sclk(iic_0_scl),
                .i2c_sdat(iic_0_sda)
              );
  i2s_tx #(
           .DATA_WIDTH(32)
         ) i2s_tx_inst (
           .reset_n(rst_n),
           .dacfifo_wrclk(clk50mhz),           // 系统时钟域写入
           .dacfifo_wren(dacfifo_write),
           .dacfifo_wrdata(dacfifo_writedata),
           .dacfifo_full(dacfifo_full),
           .bclk(I2S_BCLK),
           .daclrc(I2S_RCLK),
           .dacdat(I2S_DO)
         );



endmodule


