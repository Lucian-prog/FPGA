`timescale 1ns/1ps
// 模块: i2c_master_tb
// 说明: Alex Forencich I2C Master (AXI Stream 接口) 仿真测试台
//       使用简易 Slave 模型验证写和读事务
//
// 参考: https://github.com/alexforencich/verilog-i2c
//
// AXI Stream 接口说明:
//   - s_axis_cmd_*: 命令接口 (地址 + 读/写/启动/停止)
//   - s_axis_data_*: 写数据接口
//   - m_axis_data_*: 读数据接口

module i2c_master_tb;

  // 时钟和复位
  localparam CLK_PERIOD = 10;  // 100MHz

  reg        clk;
  reg        rst;

  // 命令接口
  reg  [6:0] s_axis_cmd_address;
  reg        s_axis_cmd_start;
  reg        s_axis_cmd_read;
  reg        s_axis_cmd_write;
  reg        s_axis_cmd_write_multiple;
  reg        s_axis_cmd_stop;
  reg        s_axis_cmd_valid;
  wire       s_axis_cmd_ready;

  // 写数据接口
  reg  [7:0] s_axis_data_tdata;
  reg        s_axis_data_tvalid;
  wire       s_axis_data_tready;
  reg        s_axis_data_tlast;

  // 读数据接口
  wire [7:0] m_axis_data_tdata;
  wire       m_axis_data_tvalid;
  reg        m_axis_data_tready;
  wire       m_axis_data_tlast;

  // I2C 接口
  wire       scl_i;
  wire       scl_o;
  wire       scl_t;
  wire       sda_i;
  wire       sda_o;
  wire       sda_t;

  // 状态
  wire       busy;
  wire       bus_control;
  wire       bus_active;
  wire       missed_ack;

  // 配置
  reg [15:0] prescale;
  reg        stop_on_idle;

  // I2C 总线（开漏模拟）
  wire scl_pin;
  wire sda_pin;

  // Slave 内部信号
  reg        sda_slave_oe;
  reg [7:0]  slave_shift;
  reg [7:0]  addr_shift;
  reg [7:0]  slave_rx_data;  // slave 接收到的数据
  reg [3:0]  bit_cnt;
  reg [2:0]  slave_state;

  localparam SL_IDLE    = 3'd0;
  localparam SL_ADDR    = 3'd1;
  localparam SL_ADDRACK = 3'd2;
  localparam SL_DATA    = 3'd3;
  localparam SL_DATAACK = 3'd4;

  // 三态总线模拟
  assign scl_pin = scl_t ? 1'bz : scl_o;
  assign sda_pin = sda_t ? 1'bz : sda_o;
  assign sda_pin = sda_slave_oe ? 1'b0 : 1'bz;

  // 上拉
  pullup(scl_pin);
  pullup(sda_pin);

  // 反馈到 master
  assign scl_i = scl_pin;
  assign sda_i = sda_pin;

  // DUT
  i2c_master dut (
    .clk                    (clk),
    .rst                    (rst),
    // 命令接口
    .s_axis_cmd_address     (s_axis_cmd_address),
    .s_axis_cmd_start       (s_axis_cmd_start),
    .s_axis_cmd_read        (s_axis_cmd_read),
    .s_axis_cmd_write       (s_axis_cmd_write),
    .s_axis_cmd_write_multiple(s_axis_cmd_write_multiple),
    .s_axis_cmd_stop        (s_axis_cmd_stop),
    .s_axis_cmd_valid       (s_axis_cmd_valid),
    .s_axis_cmd_ready       (s_axis_cmd_ready),
    // 写数据接口
    .s_axis_data_tdata      (s_axis_data_tdata),
    .s_axis_data_tvalid     (s_axis_data_tvalid),
    .s_axis_data_tready     (s_axis_data_tready),
    .s_axis_data_tlast      (s_axis_data_tlast),
    // 读数据接口
    .m_axis_data_tdata      (m_axis_data_tdata),
    .m_axis_data_tvalid     (m_axis_data_tvalid),
    .m_axis_data_tready     (m_axis_data_tready),
    .m_axis_data_tlast      (m_axis_data_tlast),
    // I2C 接口
    .scl_i                  (scl_i),
    .scl_o                  (scl_o),
    .scl_t                  (scl_t),
    .sda_i                  (sda_i),
    .sda_o                  (sda_o),
    .sda_t                  (sda_t),
    // 状态
    .busy                   (busy),
    .bus_control            (bus_control),
    .bus_active             (bus_active),
    .missed_ack             (missed_ack),
    // 配置
    .prescale               (prescale),
    .stop_on_idle           (stop_on_idle)
  );

  // 时钟生成
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  // -------------------------------------------------------
  // Simple Slave Model
  // -------------------------------------------------------
  
  // posedge scl: 采样 sda 数据位
  always @(posedge scl_pin) begin
    if (slave_state == SL_ADDR) begin
      addr_shift <= {addr_shift[6:0], sda_pin};
    end else if (slave_state == SL_DATA && !addr_shift[0]) begin
      // 写模式：接收数据
      slave_rx_data <= {slave_rx_data[6:0], sda_pin};
    end
  end

  // negedge scl: 状态机 + sda 驱动
  always @(negedge scl_pin) begin
    case (slave_state)
      SL_ADDR: begin
        if (bit_cnt == 0) begin
          slave_state  <= SL_ADDRACK;
          sda_slave_oe <= 1'b1;  // ACK
          bit_cnt      <= 7;
        end else begin
          bit_cnt      <= bit_cnt - 1'b1;
          sda_slave_oe <= 1'b0;
        end
      end

      SL_ADDRACK: begin
        slave_state  <= SL_DATA;
        slave_shift  <= 8'h3C;  // 预设读数据
        if (addr_shift[0]) begin  // 读模式
          sda_slave_oe <= ~slave_shift[7];
          slave_shift  <= {slave_shift[6:0], 1'b0};
        end else begin            // 写模式
          sda_slave_oe <= 1'b0;
        end
      end

      SL_DATA: begin
        if (bit_cnt == 0) begin
          slave_state  <= SL_DATAACK;
          sda_slave_oe <= 1'b1;  // ACK
          bit_cnt      <= 7;
        end else begin
          bit_cnt <= bit_cnt - 1'b1;
          if (addr_shift[0]) begin  // 读模式
            sda_slave_oe <= ~slave_shift[7];
            slave_shift  <= {slave_shift[6:0], 1'b0};
          end else begin
            sda_slave_oe <= 1'b0;
          end
        end
      end

      SL_DATAACK: begin
        slave_state  <= SL_IDLE;
        sda_slave_oe <= 1'b0;
      end

      default: sda_slave_oe <= 1'b0;
    endcase
  end

  // START 检测
  always @(negedge sda_pin) begin
    if (scl_pin) begin
      slave_state  <= SL_ADDR;
      addr_shift   <= 0;
      bit_cnt      <= 7;
      slave_rx_data <= 0;
    end
  end

  // -------------------------------------------------------
  // 测试任务
  // -------------------------------------------------------

  // 发送写命令
  task send_write_cmd;
    input [6:0] addr;
    input [7:0] data;
    begin
      // 发送命令
      @(posedge clk);
      s_axis_cmd_address <= addr;
      s_axis_cmd_start   <= 1'b1;
      s_axis_cmd_read    <= 1'b0;
      s_axis_cmd_write   <= 1'b1;
      s_axis_cmd_write_multiple <= 1'b0;
      s_axis_cmd_stop    <= 1'b1;
      s_axis_cmd_valid   <= 1'b1;
      
      // 等待命令被接受
      @(posedge clk);
      while (!s_axis_cmd_ready) @(posedge clk);
      @(posedge clk);
      s_axis_cmd_valid <= 1'b0;
      
      // 发送数据
      s_axis_data_tdata  <= data;
      s_axis_data_tvalid <= 1'b1;
      s_axis_data_tlast  <= 1'b1;
      
      // 等待数据被接受
      @(posedge clk);
      while (!s_axis_data_tready) @(posedge clk);
      @(posedge clk);
      s_axis_data_tvalid <= 1'b0;
      
      // 等待事务完成
      while (busy) @(posedge clk);
    end
  endtask

  // 发送读命令
  task send_read_cmd;
    input  [6:0] addr;
    output [7:0] data;
    begin
      // 发送命令
      @(posedge clk);
      s_axis_cmd_address <= addr;
      s_axis_cmd_start   <= 1'b1;
      s_axis_cmd_read    <= 1'b1;
      s_axis_cmd_write   <= 1'b0;
      s_axis_cmd_write_multiple <= 1'b0;
      s_axis_cmd_stop    <= 1'b1;
      s_axis_cmd_valid   <= 1'b1;
      
      // 等待命令被接受
      @(posedge clk);
      while (!s_axis_cmd_ready) @(posedge clk);
      @(posedge clk);
      s_axis_cmd_valid <= 1'b0;
      
      // 等待读数据
      m_axis_data_tready <= 1'b1;
      while (!m_axis_data_tvalid) @(posedge clk);
      data = m_axis_data_tdata;
      @(posedge clk);
      m_axis_data_tready <= 1'b0;
      
      // 等待事务完成
      while (busy) @(posedge clk);
    end
  endtask

  // -------------------------------------------------------
  // 测试序列
  // -------------------------------------------------------
  reg [7:0] rx_data;
  integer err;

  initial begin
    $dumpfile("i2c_master_tb.vcd");
    $dumpvars(0, i2c_master_tb);

    // 初始化
    clk                = 0;
    rst                = 1;
    s_axis_cmd_address = 0;
    s_axis_cmd_start   = 0;
    s_axis_cmd_read    = 0;
    s_axis_cmd_write   = 0;
    s_axis_cmd_write_multiple = 0;
    s_axis_cmd_stop    = 0;
    s_axis_cmd_valid   = 0;
    s_axis_data_tdata  = 0;
    s_axis_data_tvalid = 0;
    s_axis_data_tlast  = 0;
    m_axis_data_tready = 0;
    prescale           = 16'd10;  // I2C 时钟 = clk / (4 * prescale)
    stop_on_idle       = 1'b0;
    
    sda_slave_oe  = 1'b0;
    slave_shift   = 8'h3C;
    addr_shift    = 0;
    slave_rx_data = 0;
    bit_cnt       = 7;
    slave_state   = SL_IDLE;
    err           = 0;

    // 复位
    repeat(10) @(posedge clk);
    rst = 0;
    repeat(10) @(posedge clk);

    // --- 写事务测试 ---
    $display("[TEST] I2C Write: addr=0x42, data=0xA5");
    send_write_cmd(7'h42, 8'hA5);
    
    if (missed_ack) begin
      $display("[FAIL] Write transaction NACK");
      err = err + 1;
    end else begin
      $display("[PASS] Write transaction completed");
      $display("       Slave received: addr=0x%02h (R/W=%b), data=0x%02h", 
               addr_shift[7:1], addr_shift[0], slave_rx_data);
    end

    repeat(50) @(posedge clk);

    // --- 读事务测试 ---
    $display("[TEST] I2C Read: addr=0x42, expect data=0x3C");
    send_read_cmd(7'h42, rx_data);
    
    if (missed_ack) begin
      $display("[FAIL] Read transaction NACK");
      err = err + 1;
    end else if (rx_data !== 8'h3C) begin
      $display("[FAIL] Read data mismatch: got 0x%02h, expected 0x3C", rx_data);
      err = err + 1;
    end else begin
      $display("[PASS] Read transaction completed, rx_data=0x%02h", rx_data);
    end

    repeat(50) @(posedge clk);

    // 结果汇总
    if (err == 0)
      $display("\n[RESULT] i2c_master_tb: ALL TESTS PASSED");
    else
      $display("\n[RESULT] i2c_master_tb: %0d TESTS FAILED", err);

    $finish;
  end

  // 超时保护
  initial begin
    #500_000;
    $display("[TIMEOUT] i2c_master 仿真超时");
    $finish;
  end

endmodule
