module apb_slave(
  // system
  input wire sys_clk,
  input wire rst_n,
  //APB ctrl
  input wire [31:0] i_PADDR,
  input wire [31:0] i_PWDATA,
  input wire i_PWRITE,
  input wire i_PSEL,
  input [3:0] i_PSTRB,
  input wire  i_PENABLE,
  output wire o_PREADY,
  output reg  [31:0] o_PRDATA
);

reg [31:0] memory [0:1023];

parameter WAIT_CYCLES = 8;
reg [1:0] wait_cnt;
reg r_PREADY;

assign o_PREADY = r_PREADY;

always @(posedge sys_clk or negedge rst_n) begin
  if (!rst_n) begin
    wait_cnt <= 0;
    r_PREADY <= 1'b0;
  end else if (i_PSEL && i_PENABLE && !r_PREADY) begin
    if (wait_cnt == WAIT_CYCLES - 1) begin
      r_PREADY <= 1'b1;
      wait_cnt <= 0;
    end else begin
      wait_cnt <= wait_cnt + 1;
    end
  end else begin
    r_PREADY <= 1'b0;
    wait_cnt <= 0;
  end
end
integer i;

always@(posedge sys_clk or negedge rst_n) begin
  if(!rst_n)begin
    for(i=0;i<1024;i=i+1)begin
      memory[i]<=0;
    end
  end
  else if(i_PSEL && i_PENABLE && i_PWRITE) begin
    if(i_PSTRB[0]) memory[i_PADDR[11:2]][7:0]   <= i_PWDATA[7:0];
    if(i_PSTRB[1]) memory[i_PADDR[11:2]][15:8]  <= i_PWDATA[15:8];
    if(i_PSTRB[2]) memory[i_PADDR[11:2]][23:16] <= i_PWDATA[23:16];
    if(i_PSTRB[3]) memory[i_PADDR[11:2]][31:24] <= i_PWDATA[31:24];
  end
end

always@(*) begin
  if(i_PSEL && !i_PWRITE)
    o_PRDATA = memory[i_PADDR[11:2]];
  else
    o_PRDATA = 32'h0;
end

endmodule