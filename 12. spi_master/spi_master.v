module spi_master #(
    parameter integer DATA_W = 8,
    parameter integer DIV = 2   // SCLK = clk / (2*DIV), DIV >= 2
  ) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               start,
    input  wire [DATA_W-1:0]  tx_data,
    input  wire               miso,
    output reg                sclk,
    output reg                cs_n,
    output reg                mosi,
    output reg  [DATA_W-1:0]  rx_data,
    output reg                busy,
    output reg                done
  );
  localparam integer DIV_W  = $clog2(DIV);
  localparam integer BIT_W  = $clog2(DATA_W + 1);
  localparam integer IDLE   = 2'd0;
  localparam integer TRANS  = 2'd1;
  localparam integer FINISH = 2'd2;

  reg [1:0]         state;
  reg [DIV_W-1:0]   div_cnt;
  reg [BIT_W-1:0]   bit_cnt;
  reg [DATA_W-1:0]  shift_reg;

  // SPI Mode 0: CPOL=0, CPHA=0
  // - Sample MISO on rising edge
  // - Update MOSI on falling edge
  always @(posedge clk)
  begin
    if (!rst_n)
    begin
      state <= IDLE;
      sclk <= 1'b0;
      cs_n <= 1'b1;
      mosi <= 1'b0;
      rx_data <= 0;
      shift_reg <= 0;
      div_cnt <= 0;
      bit_cnt <= 0;
      busy <= 1'b0;
      done <= 1'b0;
    end
    else
    begin
      done <= 1'b0;

      case (state)
        IDLE:
        begin
          sclk <= 1'b0;
          cs_n <= 1'b1;
          busy <= 1'b0;
          div_cnt <= 0;
          bit_cnt <= 0;
          if (start)
          begin
            cs_n <= 1'b0;
            busy <= 1'b1;
            shift_reg <= tx_data;
            mosi <= tx_data[DATA_W-1];
            rx_data <= 0;
            bit_cnt <= DATA_W[BIT_W-1:0];
            state <= TRANS;
          end
        end

        TRANS:
        begin
          if (div_cnt == DIV - 1)
          begin
            div_cnt <= 0;
            sclk <= ~sclk;

            if (sclk == 1'b0)
            begin
              // Rising edge: sample MISO
              rx_data <= {rx_data[DATA_W-2:0], miso};
              if (bit_cnt == 1)
              begin
                state <= FINISH;
              end
              else
              begin
                bit_cnt <= bit_cnt - 1'b1;
              end
            end
            else
            begin
              // Falling edge: shift MOSI
              shift_reg <= {shift_reg[DATA_W-2:0], 1'b0};
              mosi <= shift_reg[DATA_W-2];
            end
          end
          else
          begin
            div_cnt <= div_cnt + 1'b1;
          end
        end

        FINISH:
        begin
          sclk <= 1'b0;
          cs_n <= 1'b1;
          busy <= 1'b0;
          done <= 1'b1;
          state <= IDLE;
        end

        default:
          state <= IDLE;
      endcase
    end
  end
endmodule
