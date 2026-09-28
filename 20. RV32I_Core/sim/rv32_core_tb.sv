`timescale 1ns/1ps

module rv32_core_tb;

  logic        clk;
  logic        rst_n;
  logic [31:0] imem_addr;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic        dmem_we;
  logic        saw_store_96;
  integer      cycle_count;

  rv32_system_top #(
    .IMEM_INIT_FILE ("programs/riscvtest.hex")
  ) dut (
    .clk_i        (clk),
    .rst_n_i      (rst_n),
    .imem_addr_o  (imem_addr),
    .dmem_addr_o  (dmem_addr),
    .dmem_wdata_o (dmem_wdata),
    .dmem_we_o    (dmem_we)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    saw_store_96 = 1'b0;
    cycle_count = 0;

    // 让低有效异步复位覆盖至少两个上升沿。
    repeat (2) @(posedge clk);
    #2 rst_n = 1'b1;
  end

  // 在下降沿观察写事务，此时地址、写数据和写使能已经稳定半个周期。
  always @(negedge clk) begin
    if (rst_n) begin
      cycle_count = cycle_count + 1;

      if (dmem_we) begin
        if (dmem_addr == 32'd96) begin
          if (dmem_wdata !== 32'd7) begin
            $fatal(1, "FAIL: address 96 received %0d, expected 7",
                   dmem_wdata);
          end
          saw_store_96 = 1'b1;
        end else if (dmem_addr == 32'd100) begin
          if (!saw_store_96) begin
            $fatal(1, "FAIL: final store occurred before store to address 96");
          end
          if (dmem_wdata !== 32'd25) begin
            $fatal(1, "FAIL: address 100 received %0d, expected 25",
                   dmem_wdata);
          end
          $display("PASS: rv32_core_tb (%0d cycles)", cycle_count);
          $finish;
        end else begin
          $fatal(1, "FAIL: unexpected store addr=%0d data=%0d",
                 dmem_addr, dmem_wdata);
        end
      end

      if (imem_addr[1:0] != 2'b00) begin
        $fatal(1, "FAIL: misaligned instruction address %h", imem_addr);
      end

      if (cycle_count >= 100) begin
        $fatal(1, "FAIL: rv32_core_tb timed out at PC=%h", imem_addr);
      end
    end
  end

endmodule
