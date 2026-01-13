module i2c_master #(
  parameter integer DATA_W = 8
) (
  input  wire               scl_in,
  input  wire               rst_n,
  input  wire               start,
  input  wire [6:0]         addr,
  input  wire               rw,
  input  wire [DATA_W-1:0]  tx_data,
  output reg  [DATA_W-1:0]  rx_data,
  output reg                busy,
  output reg                done,
  output reg                ack_error,
  output wire               scl,
  inout  wire               sda
);
  localparam integer BIT_W = $clog2(DATA_W);

  localparam integer ST_IDLE      = 4'd0;
  localparam integer ST_START     = 4'd1;
  localparam integer ST_ADDR      = 4'd2;
  localparam integer ST_ADDR_ACK  = 4'd3;
  localparam integer ST_WRITE     = 4'd4;
  localparam integer ST_WRITE_ACK = 4'd5;
  localparam integer ST_READ      = 4'd6;
  localparam integer ST_READ_ACK  = 4'd7;
  localparam integer ST_STOP      = 4'd8;

  reg [3:0]        state;
  reg [BIT_W-1:0]  bit_cnt;
  reg [7:0]        shift_reg;
  reg              sda_oe;
  reg              stop_phase;

  wire sda_in = sda;
  assign sda = sda_oe ? 1'b0 : 1'bz;
  assign scl = busy ? scl_in : 1'b1;

  always @(posedge scl_in) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      rx_data <= 0;
      shift_reg <= 0;
      bit_cnt <= 0;
      sda_oe <= 1'b0;
      busy <= 1'b0;
      done <= 1'b0;
      ack_error <= 1'b0;
      stop_phase <= 1'b0;
    end else begin
      done <= 1'b0;

      case (state)
        ST_IDLE: begin
          sda_oe <= 1'b0;
          busy <= 1'b0;
          ack_error <= 1'b0;
          stop_phase <= 1'b0;
          if (start) begin
            busy <= 1'b1;
            shift_reg <= {addr, rw};
            bit_cnt <= 7;
            sda_oe <= 1'b1;  // START: SDA low while SCL high
            state <= ST_START;
          end
        end

        ST_START: begin
          state <= ST_ADDR;
        end

        ST_ADDR: begin
          if (bit_cnt == 0) begin
            state <= ST_ADDR_ACK;
          end else begin
            bit_cnt <= bit_cnt - 1'b1;
          end
        end

        ST_ADDR_ACK: begin
          if (sda_in)
            ack_error <= 1'b1;
          if (rw) begin
            state <= ST_READ;
            bit_cnt <= DATA_W - 1;
          end else begin
            state <= ST_WRITE;
            shift_reg <= tx_data;
            bit_cnt <= DATA_W - 1;
          end
        end

        ST_WRITE: begin
          if (bit_cnt == 0) begin
            state <= ST_WRITE_ACK;
          end else begin
            bit_cnt <= bit_cnt - 1'b1;
          end
        end

        ST_WRITE_ACK: begin
          if (sda_in)
            ack_error <= 1'b1;
          state <= ST_STOP;
        end

        ST_READ: begin
          rx_data <= {rx_data[DATA_W-2:0], sda_in};
          if (bit_cnt == 0) begin
            state <= ST_READ_ACK;
          end else begin
            bit_cnt <= bit_cnt - 1'b1;
          end
        end

        ST_READ_ACK: begin
          state <= ST_STOP;
        end

        ST_STOP: begin
          if (stop_phase) begin
            sda_oe <= 1'b0;  // STOP: release SDA while SCL high
            busy <= 1'b0;
            done <= 1'b1;
            stop_phase <= 1'b0;
            state <= ST_IDLE;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

  always @(negedge scl_in) begin
    if (!rst_n) begin
      sda_oe <= 1'b0;
      stop_phase <= 1'b0;
    end else begin
      case (state)
        ST_ADDR: begin
          sda_oe <= ~shift_reg[bit_cnt];
        end
        ST_ADDR_ACK: begin
          sda_oe <= 1'b0;
        end
        ST_WRITE: begin
          sda_oe <= ~shift_reg[bit_cnt];
        end
        ST_WRITE_ACK: begin
          sda_oe <= 1'b0;
        end
        ST_READ: begin
          sda_oe <= 1'b0;
        end
        ST_READ_ACK: begin
          sda_oe <= 1'b0;  // NACK
        end
        ST_STOP: begin
          sda_oe <= 1'b1;  // pull low before STOP release
          stop_phase <= 1'b1;
        end
        default: sda_oe <= sda_oe;
      endcase
    end
  end
endmodule
