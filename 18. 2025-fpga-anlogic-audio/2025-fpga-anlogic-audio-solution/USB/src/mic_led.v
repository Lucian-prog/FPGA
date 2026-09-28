module mic_led (
    input clk_slow,       // Clock
    input rst_n,          // Reset (active low) - 新增
    input signed [5:0] mic1,
    input signed [5:0] mic2,
    input signed [5:0] mic3,
    input tVAD,
    output reg sk9822_ck,
    output reg sk9822_da,
    output reg [3:0] direction,
    output reg [3:0] direction2,
    output reg [3:0] direction3
  );


  parameter SD9822_NUM = 12;//串联灯珠数量

  parameter FRAME_LEN  = 32;//数据帧长度

  //起始帧
  parameter START_FRAME = 32'H00000000;
  //结束帧
  parameter END_FRAME   = 32'HFFFFFFFF;
  //数据帧
  parameter LED_LIGHT = 5'B01111; //全局亮度
  reg [23:0] data_rgb; //具体颜色（修正：去除初始值，在always块中初始化）
  reg [23:0] data_rgb_white = 24'b00001000_00001000_00001000;//白色
  // 删除未使用的 data_rgb_none
  wire [31:0] data_frame = {3'b111,LED_LIGHT,data_rgb};
  //大致计算一下输入方向（添加复位）
  always @(posedge clk_slow or negedge rst_n) begin
    if (!rst_n)
      direction <= 4'd15;  // 复位为静默状态
    else begin
      if(mic1 > 20)
        direction <= 4'd4;
      else if(mic1 < -20)
        direction <= 4'd10;
      else
        direction <= 4'd15;
    end
  end
  
  always @(posedge clk_slow or negedge rst_n) begin
    if (!rst_n)
      direction2 <= 4'd15;
    else begin
      if(mic2 > 20)
        direction2 <= 4'd0;   
      else if(mic2 < -20)
        direction2 <= 4'd6;   
      else
        direction2 <= 4'd15;
    end
  end
  
  always @(posedge clk_slow or negedge rst_n) begin
    if (!rst_n)
      direction3 <= 4'd15;
    else begin
      if(mic3 > 20)
        direction3 <= 4'd2;
      else if(mic3 < -20)
        direction3 <= 4'd8;
      else
        direction3 <= 4'd15;
    end
  end


  //发送状态机
  reg [31:0] send_frame;
  reg [6:0] send_frame_cnt;
  reg [4:0] send_bit_cnt;
  
  always@(posedge clk_slow or negedge rst_n)
    if (!rst_n) begin
      sk9822_ck <= 1'b0;
      sk9822_da <= 1'b0;
      send_bit_cnt <= 5'd0;
      send_frame_cnt <= 7'd0;
    end
    else if(!sk9822_ck) begin
      //上升沿发送
      sk9822_ck <= 1'b1;
    end
    else begin
      //下降沿取值
      sk9822_ck <= 1'b0;
      sk9822_da <= send_frame[(FRAME_LEN - 1) - send_bit_cnt];
      send_bit_cnt <= send_bit_cnt + 1'b1;

      if(send_bit_cnt == FRAME_LEN - 1) begin
        // 修正：需要14帧（0起始 + 1-12LED + 13结束）
        send_frame_cnt <= (send_frame_cnt < (SD9822_NUM + 1))? send_frame_cnt + 1'b1 : 7'd0;
      end
    end

  //发送数据控制
  always@(*)
    if(send_frame_cnt == 0)
      send_frame = START_FRAME;
    else if(send_frame_cnt == (SD9822_NUM + 1))
      send_frame = END_FRAME;
    else
      send_frame = data_frame;

      reg [3:0]d1_hy,d2_hy,d3_hy;

      reg [8:0]ck_cnt=0;
      reg clk_1k;
      reg [6:0]d1_cnt_4,d1_cnt_10,d2_cnt_0,d2_cnt_6,d3_cnt_2,d3_cnt_8,update_cnt;

      always@(posedge clk_slow)begin
          if(ck_cnt < 500-1)
              ck_cnt <= ck_cnt + 1'b1;
          else begin
              ck_cnt <= 10'd0;
              clk_1k <= ~clk_1k;
          end
      end

      always @(posedge clk_1k or negedge rst_n) begin
          if(!rst_n) begin
              d1_hy <= 4'd15;
              d2_hy <= 4'd15;
              d3_hy <= 4'd15;
          end
          else begin
              if(d1_cnt_4 >= 35 && d1_cnt_4 > d1_cnt_10)
                  d1_hy <= 4'd4;
              else if(d1_cnt_10 >= 20)
                  d1_hy <= 4'd10;
              else
                  d1_hy <= 4'd15;

              if(d2_cnt_0 >= 35 && d2_cnt_0 > d2_cnt_6)
                  d2_hy <= 4'd0;
              else if(d2_cnt_6 >= 20)
                  d2_hy <= 4'd6;
              else
                  d2_hy <= 4'd15;

              if(d3_cnt_2 >= 35 && d3_cnt_2 > d3_cnt_8)
                  d3_hy <= 4'd2;
              else if(d3_cnt_8 >= 20)
                  d3_hy <= 4'd8;
              else
                  d3_hy <= 4'd15;
          end
      end

      always @(posedge clk_1k or negedge rst_n) begin
          if(!rst_n) begin
              d1_cnt_4 <= 7'd0;
              d1_cnt_10 <= 7'd0;
              d2_cnt_0 <= 7'd0;
              d2_cnt_6 <= 7'd0;
              d3_cnt_2 <= 7'd0;
              d3_cnt_8 <= 7'd0;
          end
          else begin
              update_cnt <= update_cnt + 1'b1;
              if(direction == 4'd4) begin
                  if(d1_cnt_4 < 100)
                      d1_cnt_4 <= d1_cnt_4 + 1'b1;
              end
              else if(update_cnt == 7'd0)
                  d1_cnt_4 <= 7'd0;

              if(direction == 4'd10) begin
                  if(d1_cnt_10 < 100)
                      d1_cnt_10 <= d1_cnt_10 + 1'b1;
              end
              else if(update_cnt == 7'd0)
                  d1_cnt_10 <= 7'd0;

              if(direction2 == 4'd0) begin
                  if(d2_cnt_0 < 100)
                      d2_cnt_0 <= d2_cnt_0 + 1'b1;
              end
              else if(update_cnt == 7'd0)
                  d2_cnt_0 <= 7'd0;

              if(direction2 == 4'd6) begin
                  if(d2_cnt_6 < 100)
                      d2_cnt_6 <= d2_cnt_6 + 1'b1;
              end
              else if(update_cnt == 7'd0)
                  d2_cnt_6 <= 7'd0;

              if(direction3 == 4'd2) begin
                  if(d3_cnt_2 < 100)
                      d3_cnt_2 <= d3_cnt_2 + 1'b1;
              end
              else if(update_cnt == 7'd0)
                  d3_cnt_2 <= 7'd0;

              if(direction3 == 4'd8) begin
                  if(d3_cnt_8 < 100)
                      d3_cnt_8 <= d3_cnt_8 + 1'b1;
              end
              else if(update_cnt == 7'd0)
                  d3_cnt_8 <= 7'd0;
          end
      end

  //颜色转移状态机（修正：统一非阻塞赋值，添加复位）
  always@(posedge clk_slow or negedge rst_n)
  begin
    if (!rst_n)
      data_rgb <= 24'h000000;  // 复位为黑色（熄灭）
    else begin
      if ((send_frame_cnt==(d1_hy+1'b1) || 
           send_frame_cnt==(d2_hy+1'b1) || 
           send_frame_cnt==(d3_hy+1'b1)) && tVAD)
        data_rgb <= data_rgb_white;  // 点亮对应LED
      else
        data_rgb <= 24'h000000;     
    end
  end

endmodule
