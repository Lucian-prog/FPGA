module serial_lock(
        input clk,
        input rst_n,
        input [3 : 0] key_val,
        input key_valid,
        input backspace,
        input confirm,
        output  unlock,
        output  alarm,
        output [1 : 0] retry_cnt,
        output [2 : 0] input_len

    );
    parameter IDLE=2'b00;
    parameter UNLOCK=2'b01;
    parameter LOCKED=2'b10;

    reg [1:0] cur_state,next_state;
    reg [3:0] buffer[0:3];
    reg [2:0] len;
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            len<=0;
        end
        else if(cur_state==IDLE) begin
            if(confirm) begin
                len<=0;
            end
            else if(key_valid&& len<4) begin
                len<=len+1;
            end
            else if(backspace && len>0) begin
                len<=len-1;
            end
        end
    end

    always@(posedge clk) begin
        if(cur_state==IDLE&&key_valid&&len<4) begin
            buffer[len]<=key_val;
        end
    end
    wire correct = (len==3'd4)&&(buffer[0]==4'd1)&&(buffer[1]==4'd2)&&(buffer[2]==4'd3)&&(buffer[3]==4'd4);
    reg correct_latch;
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
            correct_latch <= 0;
        else if(cur_state == IDLE && !confirm)
            correct_latch <= correct;
    end
    wire error_latch = !correct_latch;
    reg [1:0] retry;
    reg [5:0] cnt_work;
    wire lock_finish;
    wire unlock_finish;
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_work <= 0;
        end
        else if(cur_state == LOCKED && cnt_work < 49) begin
            cnt_work <= cnt_work + 1;
        end
        else if(cur_state == UNLOCK && cnt_work < 9) begin
            cnt_work <= cnt_work + 1;
        end
        else begin
            cnt_work <= 0;
        end
    end
    assign lock_finish= (cnt_work==49&&cur_state==LOCKED);
    assign unlock_finish=(cnt_work==9&&cur_state==UNLOCK);
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            retry<=2;
        end
        else if(unlock_finish) begin
            retry<=2;
        end
        else if(lock_finish) begin
            retry<=2;
        end
        else if(cur_state==IDLE && confirm && error_latch) begin
            retry<=retry-1;
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cur_state<=IDLE;
        end
        else begin
            cur_state<=next_state;
        end
    end
    always@(*) begin
        case(cur_state)
            IDLE: begin
                if(confirm && correct_latch
                  ) begin
                    next_state=UNLOCK;
                end
                else if(confirm && error_latch && retry==0) begin
                    next_state=LOCKED;
                end
                else begin
                    next_state=IDLE;
                end
            end
            UNLOCK: begin
                if(unlock_finish) begin
                    next_state=IDLE;
                end
                else begin
                    next_state= UNLOCK;
                end
            end
            LOCKED: begin
                if(lock_finish) begin
                    next_state=IDLE;
                end
                else begin
                    next_state=LOCKED;
                end
            end
        endcase
    end


    assign unlock=cur_state==UNLOCK;
    assign alarm=cur_state==LOCKED;
    assign retry_cnt=retry;
    assign input_len=len;
endmodule
