`timescale 1ns/1ps

module audio_process_tb;
  reg clk = 0, rst_n = 1;
  always #10 clk = ~clk;
  reg in_valid = 0;
  wire in_ready, out_valid;
  reg signed [15:0] audio_l = 0, audio_r = 0;
  reg signed [15:0] audio_ref = 13000;
  reg [5:0] switches = 0;
  wire signed [15:0] out_l, out_r;
  AUDIO_PROCESS dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .out_valid(out_valid), .audio_l(audio_l), .audio_r(audio_r),
    .audio_ref(audio_ref), .sw0(switches[0]), .sw1(switches[1]),
    .sw2(switches[2]), .sw3(switches[3]), .sw4(switches[4]),
    .sw5(switches[5]), .o_audio_l(out_l), .o_audio_r(out_r), .tVAD()
  );

  reg ref_clk = 0;
  reg signed [15:0] ref_l = 0, ref_r = 0, ref_amp = 0;
  reg [5:0] ref_mode = 0;
  wire signed [15:0] expected_l, expected_r;
  audio_process_reference reference (
    .rst_n(rst_n), .data_async(ref_clk), .audio_l(ref_l), .audio_r(ref_r),
    .audio_ref(ref_amp), .sw0(ref_mode[0]), .sw1(ref_mode[1]),
    .sw2(ref_mode[2]), .sw3(ref_mode[3]), .sw4(ref_mode[4]),
    .sw5(ref_mode[5]), .o_audio_l(expected_l), .o_audio_r(expected_r), .tVAD()
  );

  // 独立复制控制输入同步的周期关系，不读取 DUT 的模式或状态机。
  reg [1:0] release_ref = 0;
  reg [5:0] mode_meta = 0, mode_sync = 0;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) release_ref <= 0;
    else release_ref <= {release_ref[0], 1'b1};
  end
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin mode_meta <= 0; mode_sync <= 0; end
    else if (release_ref[1]) begin mode_meta <= switches; mode_sync <= mode_meta; end
  end

  integer accepted = 0, checked = 0, aborted = 0;
  integer age = 0;
  reg pending = 0;
  reg signed [15:0] previous_l = 0, previous_r = 0;
  reg previous_valid = 0;
  always @(negedge rst_n) begin
    if (pending) aborted = aborted + 1;
    pending = 0;
    previous_l = 0;
    previous_r = 0;
    previous_valid = 0;
  end

  always @(posedge clk) begin
    if (rst_n) begin
      if (pending) age = age + 1;
      if (in_valid && in_ready) begin
        if (pending) $fatal(1, "Accepted another sample while previous result pending");
        pending = 1;
        age = 0;
        accepted = accepted + 1;
        ref_l = audio_l;
        ref_r = audio_r;
        ref_amp = audio_ref;
        ref_mode = mode_sync;
        // 参考模型每个接收事件只执行一次原版采样沿。
        #1; ref_clk = 1;
        #1; ref_clk = 0;
      end else #2;
      if (out_valid) begin
        if (!pending || previous_valid) $fatal(1, "Unexpected/duplicate output");
        if (out_l !== expected_l || out_r !== expected_r)
          $fatal(1, "Sample %0d mode=%b got=%h/%h expected=%h/%h",
                 accepted, ref_mode, out_l, out_r, expected_l, expected_r);
        if (age != 7) $fatal(1, "Unexpected latency: %0d", age);
        checked = checked + 1;
        pending = 0;
      end else if (out_l !== previous_l || out_r !== previous_r)
        $fatal(1, "Output changed without out_valid");
      if (pending && age > 12) $fatal(1, "Algorithm stalled");
      previous_l = out_l;
      previous_r = out_r;
      previous_valid = out_valid;
    end
  end

  // 固定种子 LFSR，左右声道不相同，包含全量程及负数舍入边界。
  reg [31:0] random_word = 32'h87654321;
  integer n, mode, delay_cycles;
  task drive_sample(input integer index);
    begin
      random_word = {random_word[30:0], random_word[31] ^ random_word[21] ^
                     random_word[1] ^ random_word[0]};
      case (index % 16)
        0: begin audio_l = 0; audio_r = -1; end
        1: begin audio_l = 32767; audio_r = -32768; end
        2: begin audio_l = -32768; audio_r = 32767; end
        3: begin audio_l = -1025; audio_r = 8191; end
        default: begin audio_l = random_word[15:0]; audio_r = random_word[31:16]; end
      endcase
    end
  endtask
  task reset_dut;
    begin
      in_valid = 0;
      rst_n = 0;
      #73;
      rst_n = 1;
      repeat (6) @(negedge clk);
    end
  endtask

  initial begin
    reset_dut();
    // 每种开关组合各 40 帧；valid 持续至 ready，覆盖紧邻事务与空闲。
    for (mode = 0; mode < 64; mode = mode + 1) begin
      switches = mode;
      repeat (4) @(negedge clk);
      for (n = 0; n < 40; n = n + 1) begin
        drive_sample(n);
        in_valid = 1;
        do @(posedge clk); while (!in_ready);
        @(negedge clk);
        in_valid = 0;
        // 接收后输入立即变化，结果必须只与被接收的样本有关。
        audio_l = ~audio_l;
        audio_r = ~audio_r;
        delay_cycles = n % 12;
        repeat (delay_cycles) @(negedge clk);
      end
      wait (!pending);
      @(negedge clk);
    end
    // 连续覆盖多个 AGC 长窗口，且计算期间不断切换外部控制。
    for (n = 0; n < 2200; n = n + 1) begin
      switches = n;
      drive_sample(n);
      in_valid = 1;
      do @(posedge clk); while (!in_ready);
      @(negedge clk);
      in_valid = 0;
      switches = ~switches;
      audio_ref = (n % 2) ? 16'd13000 : 16'd8000;
    end
    wait (!pending);
    @(negedge clk);
    // 遍历算法各计算阶段的复位中止，不能产生旧结果。
    for (n = 0; n < 7; n = n + 1) begin
      in_valid = 1;
      drive_sample(n);
      do @(posedge clk); while (!in_ready);
      @(negedge clk);
      in_valid = 0;
      repeat (n) @(negedge clk);
      reset_dut();
      repeat (12) @(negedge clk);
    end
    // 复位后继续正常输出。
    for (n = 0; n < 64; n = n + 1) begin
      switches = n;
      drive_sample(n);
      in_valid = 1;
      do @(posedge clk); while (!in_ready);
      @(negedge clk); in_valid = 0;
    end
    wait (!pending);
    repeat (20) @(negedge clk);
    if (accepted != checked + aborted || aborted != 7)
      $fatal(1, "Accounting failed accepted=%0d checked=%0d aborted=%0d",
             accepted, checked, aborted);
    $display("PASS: accepted=%0d checked=%0d aborted=%0d; bit-exact old algorithm, all modes, reset, handshake",
             accepted, checked, aborted);
    $finish;
  end
  initial begin #10000000; $fatal(1, "Timeout"); end
endmodule
