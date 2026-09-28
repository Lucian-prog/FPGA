`timescale 1ps/1ps
module sync_fifo #(
        parameter DATA_WIDTH = 8,
        parameter DATA_DEPTH = 16
    )
    ( input wire i_sys_clk,
      input wire i_sys_rst_n,
      input wire i_wren,
      input wire i_rden,
      input wire [DATA_WIDTH-1:0] i_wdata,
      output wire [DATA_WIDTH-1:0] o_rdata,
      output wire o_full,
      output wire o_empty
    );
    reg [DATA_WIDTH-1:0] mem_ram [0:DATA_DEPTH-1];
    reg [$clog2(DATA_DEPTH)-1:0] r_wr_ptr;
    reg [$clog2(DATA_DEPTH)-1:0] r_rd_ptr;
    reg [$clog2(DATA_DEPTH):0] fifo_number;
    reg [DATA_WIDTH-1:0] r_rdata;

    wire w_en = i_wren && !o_full;
    wire r_en = i_rden && !o_empty;

    assign o_empty = (fifo_number == 0);
    assign o_full  = (fifo_number == DATA_DEPTH);
    assign o_rdata = r_rdata;

    always@(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if(!i_sys_rst_n)
            r_wr_ptr <= 0;
        else if(w_en)
            r_wr_ptr <= r_wr_ptr + 1'b1;
    end

    always@(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if(!i_sys_rst_n)
            r_rd_ptr <= 0;
        else if(r_en)
            r_rd_ptr <= r_rd_ptr + 1'b1;
    end

    always@(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if(!i_sys_rst_n)
            r_rdata <= 0;
        else if(r_en)
            r_rdata <= mem_ram[r_rd_ptr];
    end

    always@(posedge i_sys_clk) begin
        if(w_en)
            mem_ram[r_wr_ptr] <= i_wdata;
    end

    always@(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if(!i_sys_rst_n)
            fifo_number <= 0;
        else if(w_en && !r_en)
            fifo_number <= fifo_number + 1'b1;
        else if(!w_en && r_en)
            fifo_number <= fifo_number - 1'b1;
        else
            fifo_number <= fifo_number;
    end

endmodule
