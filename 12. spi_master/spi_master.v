module spi_master #(
  parameter integer DATA_W = 8
) (
  input  wire               sclk_in,
  input  wire               rst_n,
  input  wire               start,
  input  wire [DATA_W-1:0]  tx_data,
  input  wire               miso,
  output wire               sclk,
  output reg                cs_n,
  output reg                mosi,
  output reg  [DATA_W-1:0]  rx_data,
  output reg                busy,
  output reg                done
);
  localparam integer BIT_W  = $clog2(DATA_W + 1);
  localparam integer IDLE   = 2'd0;
  localparam integer TRANS  = 2'd1;
  localparam integer FINISH = 2'd2;

  reg [1:0]        state;
  reg [BIT_W-1:0]  bit_cnt;
  reg [DATA_W-1:0] shift_reg;

  // SPI Mode 0: CPOL=0, CPHA=0
  // - Sample MISO on rising edge
  // - Update MOSI on falling edge
  assign sclk = busy ? sclk_in : 1'b0;

  always @(posedge sclk_in) begin
    if (!rst_n) begin
      state <= IDLE;
      cs_n <= 1'b1;
      mosi <= 1'b0;
      rx_data <= 0;
      shift_reg <= 0;
      bit_cnt <= 0;
      busy <= 1'b0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          cs_n <= 1'b1;
          busy <= 1'b0;
          bit_cnt <= 0;
          if (start) begin
            cs_n <= 1'b0;
            busy <= 1'b1;
            shift_reg <= tx_data;
            mosi <= tx_data[DATA_W-1];
            rx_data <= 0;
            bit_cnt <= DATA_W[BIT_W-1:0];
            state <= TRANS;
          end
        end

        TRANS: begin
          rx_data <= {rx_data[DATA_W-2:0], miso};
          if (bit_cnt == 1) begin
            state <= FINISH;
          end else begin
            bit_cnt <= bit_cnt - 1'b1;
          end
        end

        FINISH: begin
          cs_n <= 1'b1;
          busy <= 1'b0;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

  always @(negedge sclk_in) begin
    if (!rst_n) begin
      shift_reg <= 0;
      mosi <= 1'b0;
    end else if (state == TRANS && bit_cnt > 1) begin
      shift_reg <= {shift_reg[DATA_W-2:0], 1'b0};
      mosi <= shift_reg[DATA_W-2];
    end
  end
endmodule
