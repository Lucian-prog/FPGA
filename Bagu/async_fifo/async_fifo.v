module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16
) (
    input  wire clk_wr,
    input  wire clk_rd,
    input  wire rst_n,
    input  wire wr_en,
    input  wire rd_en,
    input  wire [DATA_WIDTH-1:0] data_wr,
    output wire [DATA_WIDTH-1:0] data_rd,
    output wire full,
    output wire empty
);
  reg [$clog2(FIFO_DEPTH):0] wr_ptr, rd_ptr;

  always @(posedge clk_wr or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= 0;
    end else if (wr_en && !full) begin
      wr_ptr <= wr_ptr + 1;
    end
  end

  always @(posedge clk_rd or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr <= 0;
    end else if (rd_en && !empty) begin
      rd_ptr <= rd_ptr + 1;
    end
  end

  wire [$clog2(FIFO_DEPTH):0] wr_ptr_gray, rd_ptr_gray;

  assign wr_ptr_gray = (wr_ptr >> 1) ^ wr_ptr;
  assign rd_ptr_gray = (rd_ptr >> 1) ^ rd_ptr;

  reg [$clog2(FIFO_DEPTH):0] wr_ptr_gray_sync0, wr_ptr_gray_sync1;
  reg [$clog2(FIFO_DEPTH):0] rd_ptr_gray_sync0, rd_ptr_gray_sync1;

  always @(posedge clk_rd or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr_gray_sync0 <= 0;
      wr_ptr_gray_sync1 <= 0;
    end else begin
      wr_ptr_gray_sync0 <= wr_ptr_gray;
      wr_ptr_gray_sync1 <= wr_ptr_gray_sync0;
    end
  end

  always @(posedge clk_wr or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr_gray_sync0 <= 0;
      rd_ptr_gray_sync1 <= 0;
    end else begin
      rd_ptr_gray_sync0 <= rd_ptr_gray;
      rd_ptr_gray_sync1 <= rd_ptr_gray_sync0;
    end
  end
  
  assign full = (wr_ptr_gray == {~rd_ptr_gray_sync1[$clog2(FIFO_DEPTH)   : $clog2(FIFO_DEPTH)-1],
                                   rd_ptr_gray_sync1[$clog2(FIFO_DEPTH)-2 : 0]});
  assign empty = (rd_ptr_gray == wr_ptr_gray_sync1);

  async_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(FIFO_DEPTH)
  ) ram_inst (
    .clk_wr(clk_wr),
    .clk_rd(clk_rd),
    .rst_n(rst_n),
    .data_in(data_wr),
    .addr_wr(wr_ptr[$clog2(FIFO_DEPTH)-1:0]),
    .addr_rd(rd_ptr[$clog2(FIFO_DEPTH)-1:0]),
    .we(wr_en && !full),
    .re(rd_en && !empty),
    .data_out(data_rd)
  );

endmodule

