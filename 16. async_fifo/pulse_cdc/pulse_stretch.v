module pulse_stretch(
    input wire clk,
    input wire rst_n,
    input wire pulse,
    output reg pulse_stretch,
    output wire pulse_stretch_valid
);
    reg level;
    reg [2:0] cnt;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            level<=0;
            cnt<=0;
        end

        else if(pulse)begin
            cnt<=3'd4;
            level<=1;
        end
        else if(cnt!=0)begin
            cnt<=cnt-1;
            if(cnt==1)begin
                level<=0;
            end
        end
    end
    reg pulse_stretch_d;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            pulse_stretch<=0;
            pulse_stretch_d<=0;
        end
        else begin
            pulse_stretch<=level;
            pulse_stretch_d<=pulse_stretch;
        end
    end
    assign pulse_stretch_valid=pulse_stretch & ~pulse_stretch_d;
endmodule