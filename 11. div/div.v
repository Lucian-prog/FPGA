module div #(
    parameter integer DIV = 2  // DIV >= 2
  ) (
    input  wire clk,
    input  wire rst_n,
    output reg  clk_out
  );
  localparam integer CNT_W = $clog2(DIV);
  localparam integer HALF_FLOOR = DIV / 2;
  localparam integer HALF_CEIL  = HALF_FLOOR + 1;
  localparam integer EVEN_DIV   = (DIV % 2) == 0;

  reg [CNT_W-1:0] cnt;
  reg             odd_phase;

  always @(posedge clk)
  begin
    if (!rst_n)
    begin
      cnt <= 0;
      clk_out <= 1'b0;
      odd_phase <= 1'b0;
    end
    else
    begin
      if (EVEN_DIV)
      begin
        if (cnt == (HALF_FLOOR - 1))
        begin
          cnt <= 0;
          clk_out <= ~clk_out;
        end
        else
        begin
          cnt <= cnt + 1'b1;
        end
      end
      else
      begin   //交替
        if (!odd_phase)
        begin
          if (cnt == (HALF_FLOOR - 1))
          begin
            cnt <= 0;
            odd_phase <= 1'b1;
            clk_out <= ~clk_out;
          end
          else
          begin
            cnt <= cnt + 1'b1;
          end
        end
        else
        begin
          if (cnt == (HALF_CEIL - 1))
          begin
            cnt <= 0;
            odd_phase <= 1'b0;
            clk_out <= ~clk_out;
          end
          else
          begin
            cnt <= cnt + 1'b1;
          end
        end
      end
    end
  end
endmodule
