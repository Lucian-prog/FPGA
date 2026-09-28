
module agc(
input clk,
input rst_n,
input signed [23:0]din,
input signed [15:0]exp_amp,
output reg signed [15:0]dout
    );
    
    reg signed [15:0]amp;
    wire signed [15:0]abs_dout = (dout > 0) ? dout : -dout;
    wire [14:0]ufb = abs_dout[14:0];
    wire signed [15:0]din_cut = din[23:8];
    
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            dout <= 0;
        end else begin
            dout <= (din_cut * amp)/8192;
        end
    end
    
    reg [24:0]long_fb_sum;
    reg [19:0]short_fb_sum;
    reg [14:0]long_ave,short_ave;
    wire [15:0]slong_ave,sshort_ave;
    reg [9:0]cnt;
    reg ldu_flag,sdu_flag;
    
    assign slong_ave = {1'b0,long_ave};
    assign sshort_ave = {1'b0,short_ave};
    
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            long_fb_sum <= 0;
            short_fb_sum <= 0;
            ldu_flag <= 0;
            sdu_flag <= 0;
            cnt <= 0;
        end else begin
            cnt <= cnt + 1;
            if(cnt == 1)begin
                long_fb_sum <= 0;
                long_ave <= long_fb_sum[24:10];
                ldu_flag <= 1;
            end else begin
                long_fb_sum <= long_fb_sum + ufb;
                ldu_flag <= 0;
            end
            if(cnt[4:0] == 2)begin
                short_fb_sum <= 0;
                short_ave <= short_fb_sum[19:5];
                sdu_flag <= 1;
            end else begin
                short_fb_sum <= short_fb_sum + ufb;
                sdu_flag <= 0;
            end
        end
    end 
    
    wire signed [15:0]ldd,sdd;
    wire clamp_up,clamp_down;
    assign ldd = exp_amp - slong_ave;
    assign sdd = exp_amp - sshort_ave;
    assign clamp_up = amp > 24576;
    assign clamp_down = amp < 2048;
    
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            amp <= 8192;
        end else begin
            if(ldu_flag)begin
                if(clamp_up && ldd < 0)begin
                    amp <= amp + (ldd>>>2);
                end else if(clamp_down && ldd > 0)begin
                    amp <= amp + (ldd>>>2);
                end else if((!clamp_up) && (!clamp_down))begin
                    amp <= amp + (ldd>>>2);
                end
            end else if(sdu_flag)begin
                if(clamp_up && sdd < 0)begin
                    amp <= amp + (sdd>>>4);
                end else if(clamp_down && sdd > 0)begin
                    amp <= amp + (sdd>>>4);
                end else if((!clamp_up) && (!clamp_down))begin
                    amp <= amp + (sdd>>>4);
                end
            end
        end
    end 
    
endmodule