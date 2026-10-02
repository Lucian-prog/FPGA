module apb_master (
    //clk and rst_n
    input wire sys_clk,
    input wire rst_n,
    //User ctrl
    input wire i_en,
    input wire i_write,
    input wire [31:0] i_addr,
    input wire [31:0] i_wdata,
    output wire [31:0] o_rdata,
    output wire o_tran_done,
    //connection to APB Slave
    output wire [31:0] o_PADDR,
    output wire [31:0] o_PWDATA,
    input wire [31:0] i_PRDATA,
    output wire o_PWRITE,
    output wire o_SEL,
    output wire o_PENABLE,
    input wire i_PREADY,
    output wire [3:0] o_PSTRB

);

  //FSM state
  localparam IDLE = 6'b000001;
  localparam WRITE = 6'b000010;
  localparam READ = 6'b000100;
  localparam ENABLE = 6'b001000;
  localparam DONE = 6'b010000;
  localparam WAIT = 6'b100000;

  //State
  reg [5:0] cur_state, next_state;

  //APB registers
  reg [31:0] r_PADDR;
  reg [31:0] r_PWDATA;
  reg r_PWRITE;
  reg r_PSEL;
  reg r_PENABLE;
  reg [3:0] r_PSTRB;
  reg r_trans_done;
  reg [31:0] r_PRDATA;

  //paragraph1
  always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_state <= IDLE;
    end else cur_state <= next_state;
  end

  //paragraph2
  always @(*) begin
    if (!rst_n) begin
      next_state = IDLE;
    end else begin
      case (cur_state)
        IDLE: begin
          if (i_en) begin
            if (i_write) next_state = WRITE;
            else next_state = READ;
          end else next_state = IDLE;
        end

        WRITE: begin
          next_state = ENABLE;
        end

        READ: begin
          next_state = ENABLE;
        end

        ENABLE: begin
          if (i_PREADY) next_state = DONE;
          else          next_state = ENABLE;
        end

        DONE: begin
          next_state = WAIT;
        end

        WAIT: begin
          next_state = IDLE;
        end

        default: next_state = IDLE;
      endcase
    end
  end

  //paragraph3
  always@(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)begin
      r_PADDR      <= 32'h0;
      r_PWDATA     <= 32'h0;
      r_PWRITE     <= 1'b0;
      r_PSEL       <= 1'b0;
      r_PENABLE    <= 1'b0;
      r_PSTRB      <= 4'h0;
      r_trans_done <= 1'b0;
      r_PRDATA     <= 32'h0;
    end
    else begin
      case(cur_state)
      IDLE:begin
        r_PADDR      <= 32'h0;
        r_PWDATA     <= 32'h0;
        r_PWRITE     <= 1'b0;
        r_PSEL       <= 1'b0;
        r_PENABLE    <= 1'b0;
        r_PSTRB      <= 4'h0;
        r_trans_done <= 1'b0;
      end

      WRITE:begin
        r_PADDR  <= i_addr;
        r_PWDATA <= i_wdata;
        r_PWRITE <= 1'b1;
        r_PSEL   <= 1'b1;
        r_PENABLE<= 1'b0;
        r_PSTRB  <= 4'h0;
      end

      READ:begin
        r_PADDR  <= i_addr;
        r_PWRITE <= 1'b0;
        r_PSEL   <= 1'b1;
        r_PENABLE<= 1'b0;
      end

      ENABLE:begin
        r_PENABLE <= 1'b1;
      end

      DONE:begin
        r_PSEL    <= 1'b0;
        r_PENABLE <= 1'b0;
      end

      WAIT:begin
        r_trans_done <= 1'b1;
        r_PRDATA     <= i_PRDATA;
      end
      endcase
    end
  end
endmodule

