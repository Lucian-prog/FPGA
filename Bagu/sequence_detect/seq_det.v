module seq_det(
            input wire clk,
            input wire rst_n,
            input wire din,
            input wire din_valid,
            output reg flag
        );
        localparam IDLE = 6'b000001;   // 未匹配
        localparam S1   = 6'b000010;   // 已匹配 "1"
        localparam S2   = 6'b000100;   // 已匹配 "10"
        localparam S3   = 6'b001000;   // 已匹配 "101"
        localparam S4   = 6'b010000;   // 已匹配 "1011"
        localparam S5   = 6'b100000;   // 命中 "10110"（转移镜像 S2，支持重叠检测）

        reg [5:0] current_state, next_state;
        //第一段：时序逻辑，同步复位
        always@(posedge clk) begin
            if(!rst_n) begin
                current_state <= IDLE;
            end
            else begin
                current_state <= next_state;
            end
        end

        //第二段：组合逻辑，次态译码（din_valid 全局门控）
        always@(*) begin
            next_state = current_state;     // 默认自保持，防锁存器
            if(din_valid) begin
                case(current_state)
                    IDLE: begin
                        if(din) begin
                            next_state = S1;
                        end
                        else begin
                            next_state = IDLE;
                        end
                    end
                    S1: begin
                        if(!din) begin
                            next_state = S2;
                        end
                        else begin
                            next_state = S1;
                        end
                    end
                    S2: begin
                        if(din) begin
                            next_state = S3;
                        end
                        else begin
                            next_state = IDLE;
                        end
                    end
                    S3: begin
                        if(din) begin
                            next_state = S4;
                        end
                        else begin
                            next_state = S2;   // "1010" 后缀 "10" 仍是前缀
                        end
                    end

                    S4: begin
                        if(!din) begin
                            next_state = S5;   // 命中 "10110"
                        end
                        else begin
                            next_state = S1;   // "10111" 后缀 "1" 仍是前缀
                        end
                    end

                    S5: begin
                        if(din) begin
                            next_state = S3;   // 镜像 S2："10"+1="101"，重叠检测关键
                        end
                        else begin
                            next_state = IDLE;
                        end
                    end

                    default: next_state = IDLE;    // 非法编码恢复
                endcase
            end
        end


        //第三段：Moore 输出，S5 期间为高
        always@(*) begin
            case(current_state)
                S5: begin
                    flag = 1'b1;
                end
                default: begin
                    flag = 1'b0;
                end
            endcase
        end


    endmodule
