`timescale 1ps/1ps
module sync_fifo #(
        parameter DATA_WIDTH =8,
        parameter DATA_DEPTH =16
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
    function integer clogb2(input integer data);
        begin
            for(clogb2=0;data>0;clogb2= clogb2+1)
                data =data>>1;
        end
    endfunction

    reg [DATA_WIDTH-1:0] mem_ram [0:DATA_DEPTH-1];
    reg [clogb2(DATA_DEPTH-1)-1:0] r_wr_ptr;
    reg [clogb2(DATA_DEPTH-1)-1:0] r_rd_ptr;
    always@(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if(!i_sys_rst_n)
            r_wr_ptr<=0;
        else if(i_wren && !o_full)
            r_wr_ptr<=r_wr_ptr+1;
        else
            r_wr_ptr<=r_wr_ptr;
    end

    always@(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if(!i_sys_rst_n)
            r_rd_ptr<=0;
        else if(i_rden && !o_empty)
            r_rd_ptr<=r_rd_ptr+1;
        else
            r_rd_ptr<=r_rd_ptr;
    end
    reg [DATA_WIDTH-1:0] r_rdata;
    always@(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if(!i_sys_rst_n) begin
            r_rdata<=0;
        end
        else if(i_rden && !o_empty) begin
            r_rdata<=mem_ram[r_rd_ptr];
        end
    end


    integer i;

    always@(posedge i_sys_clk or negedge i_sys_rst_n) begin
        if(!i_sys_rst_n) begin
            for(i=0;i<DATA_DEPTH;i=i+1) begin
                mem_ram[i]<=0;
            end
        end
        else if(i_wren && !o_full)begin
           mem_ram[r_wr_ptr] <=i_wdata;
        end
    end

    reg [clogb2(DATA_DEPTH-1):0] fifo_number;
    always@(posedge i_sys_clk or negedge i_sys_rst_n)begin
        if(!i_sys_rst_n)begin
            fifo_number<=0;
        end
        else if(i_wren && i_rden && !o_full && !o_empty)begin
            fifo_number<=fifo_number;
        end
        else if(i_wren && !i_rden && !o_full)begin
            fifo_number<=fifo_number+1;
        end
        else if(!i_wren && i_rden && !o_empty)begin
            fifo_number<=fifo_number-1;
        end
        else begin
            fifo_number<=fifo_number;
        end
    end

    assign o_empty =(fifo_number==0);
    assign o_full =(fifo_number==DATA_DEPTH);
    assign o_rdata = r_rdata;
endmodule
