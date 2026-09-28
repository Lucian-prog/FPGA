module xcorr(input clk,
             input rst_n,
             input start_flag,
             input finish_left,
             input finish_right,
             input signed[17:0]mic_1,
             input signed[17:0]mic_2,
             output reg[5:0]sequence_num,
             output reg finished,
             output reg finished_temp1);
    
    reg finished_temp;
    wire data_ok_1_flag;
    wire data_ok_2_flag;
    reg data_ok_1_flag_temp;
    reg data_ok_2_flag_temp;
    reg data_ok_all_flag;
    reg [10:0]mic_1_cnt;
    reg [10:0]mic_2_cnt;
    reg [5:0]shift_index;
    reg signed[35:0] mul_add_result;
    
    
    reg [10:0]address_1;
    reg [10:0]address_2;
    wire signed[17:0]data_out_1;
    wire signed[17:0]data_out_2;
    reg signed[35:0] mul_add_max;
    
    parameter state_0 = 3'b000 ;
    parameter state_1 = 3'b001 ;
    parameter state_2 = 3'b010 ;
    parameter state_3 = 3'b011 ;
    parameter state_4 = 3'b100 ;
    parameter state_5 = 3'b101 ;
    reg [2:0]state;
    initial begin
        // data_ok_1_flag   = 0;
        // data_ok_2_flag   = 0;
        sequence_num        = 0;
        data_ok_1_flag_temp = 0;
        data_ok_2_flag_temp = 0;
        data_ok_all_flag    = 0;
        mic_1_cnt           = 0;
        mic_2_cnt           = 0;
        shift_index         = 0;
        mul_add_result      = 0;
        address_1           = 0;
        address_2           = 0;
        mul_add_max         = 0;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
        begin
            data_ok_1_flag_temp <= 0;
            data_ok_2_flag_temp <= 0;
            finished_temp       <= 0;
            finished_temp1      <= 0;
        end
        else
        begin
            data_ok_1_flag_temp <= data_ok_1_flag;
            data_ok_2_flag_temp <= data_ok_2_flag;
            finished_temp       <= finished;
            finished_temp1      <= finished_temp;
            
        end
        
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
        begin
            data_ok_all_flag = 0;
        end
        else if ((data_ok_1_flag_temp&&!data_ok_1_flag))
        begin
            data_ok_all_flag <= 1;
        end
            
            end
            
            
            
            
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                begin
                    state = state_0;
                    mic_1_cnt <= 0;
                    mic_2_cnt <= 0;
                    shift_index    = 0;
                    finished       = 0;
                    mul_add_max    = 0;
                    mul_add_result = 0;
                end
                else
                begin
                    case (state)
                        state_0://初始
                        begin
                            if (data_ok_all_flag)
                            begin
                                mic_1_cnt <= 0;
                                state     <= state_1;
                            end
                        end
                        state_1://左移
                        begin
                            
                            if (mic_1_cnt == 1023-shift_index)
                                state                         = state_3;
                                //mul_add_result[shift_index] = mul_add_result[shift_index]+data_out_1*data_out_2;
                                mul_add_result                = mul_add_result+data_out_1*data_out_2;
                                mic_1_cnt                     = mic_1_cnt+1;
                                mic_2_cnt                     = mic_2_cnt+1;
                                end
                                state_2://右移
                                begin
                            
                            if (mic_1_cnt == shift_index-30)
                                state                          = state_3;
                                mul_add_result                 = mul_add_result+data_out_1*data_out_2;
                                mic_1_cnt                      = mic_1_cnt-1;
                                mic_2_cnt                      = mic_2_cnt-1;
                                // mul_add_result[shift_index] = mul_add_result[shift_index]+data_out_1*data_out_2;
                                end
                                state_3://shift_index++
                                begin
                                if (mul_add_result>mul_add_max)
                                begin
                                    mul_add_max  = mul_add_result;
                                    sequence_num = shift_index;
                                end
                                mul_add_result = 0;
                                shift_index    = shift_index+1;
                                if (shift_index <= 30)
                                begin
                                    state     <= state_1;
                                    mic_1_cnt <= 0;
                                    mic_2_cnt <= shift_index;
                                end
                                else if (shift_index<61)
                                begin
                                    state = state_2;
                                    mic_1_cnt <= 1023;
                                    mic_2_cnt <= 1023-(shift_index-30);
                                end
                                else
                                begin
                                    shift_index = 0;
                                    state       = state_4;
                                end
                            
                        end
                        state_4://结束
                        begin
                            finished = 1;
                            
                        end
                        state_5:
                        begin
                            finished = 0;
                        end
                    endcase
                end
            end
            
          
            mic_data_store mic_data_store_inst1(
            .clk(clk),
            .rst_n(rst_n),
            .mic_1(mic_1),
            .start(start_flag),
            .output_flag(data_ok_all_flag),
            .finish_left_or_right(finish_right),
            .adb_cnt(mic_1_cnt[9:0]),
            .out_data(data_out_1),
            .output_start_flag(data_ok_1_flag));
            
            mic_data_store mic_data_store_inst2(
            .clk(clk),
            .rst_n(rst_n),
            .mic_1(mic_2),
            .start(start_flag),
            .output_flag(data_ok_all_flag),
            .finish_left_or_right(finish_left),
            .adb_cnt(mic_2_cnt[9:0]),
            .out_data(data_out_2),
            .output_start_flag(data_ok_2_flag));
            
            
            
            
            
            endmodule
