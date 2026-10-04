`timescale 1ns/1ps

module i2s_receive_tb;
  reg clk = 1'b0;
  reg rst_n = 1'b1;
  reg [3:0] sd = 4'b0000;
  wire bclk, ws, finished_left, finished_right, start;
  wire signed [23:0] mic [0:6];

  always #10 clk = ~clk;

  // 包含原始分频器、接收器，以及后续并行数据流水线。
  mic_serial dut (
    .clk(clk), .rst_n(rst_n), .rst_dsp(rst_n),
    .mic_clk(bclk), .mic_ws(ws), .mic_so(sd),
    .mic_0(mic[0]), .mic_1(mic[1]), .mic_2(mic[2]),
    .mic_3(mic[3]), .mic_4(mic[4]), .mic_5(mic[5]),
    .mic_6(mic[6]), .finished_left1(finished_left),
    .finished_right1(finished_right), .start(start)
  );

  reg last_ws = 1'b0;
  reg pad_z;
  integer bit_pos = 0;
  integer frame_id = -1, left_id = -1, right_id = -1;
  integer lane, epoch, previous_checks;
  integer checks = 0, errors = 0;
  integer left_events = 0, right_events = 0;
  integer previous_left, previous_right;
  integer tx_delay;
  reg [23:0] left_word [0:3];
  reg [23:0] right_word [0:3];

  function [23:0] sample_word(input integer frame, input integer channel);
    reg [23:0] value;
    begin
      case (frame - 3)
        0: value = 24'h000000;
        1: value = 24'hffffff;
        2: value = 24'h7fffff;
        3: value = 24'h800000;
        4: value = 24'h200000;
        5: value = 24'hdfffff;
        6: value = 24'h010000;
        7: value = 24'hff0000;
        default: begin
          if (frame < 35)
            value = 24'h000001 << (frame - 11);
          else
            value = (frame * 32'h00123457) ^ (frame << 13);
        end
      endcase
      // 各数据线、左右声道使用不同内容，避免通道接错也通过。
      sample_word = value ^ (channel * 24'h010123);
    end
  endfunction

  // 独立发送模型只观察引脚 WS，不读取 DUT 的 b_cnt。
  // WS 切换的下降沿为位置 0；下一下降沿的位置 1 发送 MSB。
  // 延迟同时避开分频器更新 WS 的 NBA 区域，并模拟发送传播延迟。
  always @(negedge bclk or negedge rst_n) begin
    if (!rst_n) begin
      last_ws = 1'b0;
      bit_pos = 0;
      frame_id = -1;
      left_id = -1;
      right_id = -1;
      sd = 4'b0000;
    end
    else begin
      #(tx_delay);
      if (ws !== last_ws) begin
        bit_pos = 0;
        if (!ws) begin
          frame_id = frame_id + 1;
          left_id = frame_id;
          for (lane = 0; lane < 4; lane = lane + 1)
            left_word[lane] = sample_word(frame_id, 2*lane + 1);
        end
        else begin
          right_id = frame_id;
          for (lane = 0; lane < 4; lane = lane + 1)
            right_word[lane] = sample_word(frame_id, 2*lane);
        end
      end
      else
        bit_pos = bit_pos + 1;
      last_ws = ws;
      for (lane = 0; lane < 4; lane = lane + 1) begin
        if (bit_pos >= 1 && bit_pos <= 24)
          sd[lane] = ws ? right_word[lane][24-bit_pos]
                        : left_word[lane][24-bit_pos];
        else
          sd[lane] = pad_z ? 1'bz : 1'b0;
      end
    end
  end

  task check_sample(input integer channel, input [23:0] expected,
                    input [23:0] raw, input [23:0] piped);
    begin
      checks = checks + 1;
      if (raw !== expected || piped !== expected) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("MISMATCH channel=%0d expected=%h raw=%h piped=%h",
                   channel, expected, raw, piped);
      end
    end
  endtask

  // 等待 50 MHz 三级寄存器更新后，同时检查接收器原始输出和 mic 输出。
  // 本用例验证锁定帧边界后的保真；不将启动阶段的 finished 当有效帧。
  always @(posedge finished_left) begin
    #100;
    if (rst_n && left_id >= 3 && left_id <= 102) begin
      left_events = left_events + 1;
      check_sample(1, left_word[0], dut.mic_data_left1, mic[1]);
      check_sample(3, left_word[1], dut.mic_data_left2, mic[3]);
      check_sample(5, left_word[2], dut.mic_data_left3, mic[5]);
    end
  end

  always @(posedge finished_right) begin
    #100;
    if (rst_n && right_id >= 3 && right_id <= 102) begin
      right_events = right_events + 1;
      check_sample(0, right_word[0], dut.mic_data_right1, mic[0]);
      check_sample(2, right_word[1], dut.mic_data_right2, mic[2]);
      check_sample(4, right_word[2], dut.mic_data_right3, mic[4]);
      check_sample(6, right_word[3], dut.mic_data_right4, mic[6]);
    end
  end

  initial begin
    pad_z = $test$plusargs("PAD_Z");
    tx_delay = 1;
    for (epoch = 0; epoch < 2; epoch = epoch + 1) begin
      previous_checks = checks;
      previous_left = left_events;
      previous_right = right_events;
      rst_n = 1'b0;
      #1003;
      rst_n = 1'b1;
      wait (frame_id == 103);
      #1000;
      if (checks - previous_checks != 700 ||
          left_events - previous_left != 100 ||
          right_events - previous_right != 100)
        $fatal(1, "Missing or duplicate sample events after frame alignment");
      // 下一轮从一帧中途复位，并改变发送端传播延迟。
      repeat (9) @(posedge bclk);
      #7;
      tx_delay = 37;
    end
    $display("RESULT pad_z=%b checks=%0d errors=%0d", pad_z, checks, errors);
    if (errors != 0)
      $fatal(1, "PCM samples are not bit-exact");
    $display("PASS: bit-exact PCM across all seven channels and reset recovery");
    $finish;
  end

  initial begin
    #10000000;
    $fatal(1, "Timeout");
  end
endmodule
