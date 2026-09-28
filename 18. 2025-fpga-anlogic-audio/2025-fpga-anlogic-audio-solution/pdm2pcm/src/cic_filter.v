//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/03
// Design Name: Cascaded Integrator-Comb (CIC) Filter
// Module Name: cic_filter
// Description: Configurable CIC filter for PDM decimation
//              - M stages of integrators
//              - Decimation by R
//              - M stages of combs
//////////////////////////////////////////////////////////////////////////////////

module cic_filter #(
    parameter M = 5,              // Number of stages
    parameter R = 50,             // Decimation ratio
    parameter W = 1               // Input bit width (1 for PDM)
)(
    input wire clk,               // System clock
    input wire rst_n,             // Active low reset
    input wire ena,               // Enable signal
    
    input wire [W-1:0] data_in,   // Input data
    input wire fs_in,             // Input sampling pulse
    
    output reg [W+M*$clog2(R)-1:0] data_out,  // Output data
    output reg valid_out          // Output valid signal
);

    localparam OUT_WIDTH = W + M * $clog2(R);
    localparam CNT_WIDTH = $clog2(R);
    
    // Decimation counter
    reg [CNT_WIDTH-1:0] dec_cnt;
    wire dec_ena;
    
    // Integrator stages
    reg [OUT_WIDTH-1:0] integ [0:M-1];
    reg [OUT_WIDTH-1:0] integ_d [0:M-1];
    
    // Comb stages
    reg [OUT_WIDTH-1:0] comb [0:M-1];
    reg [OUT_WIDTH-1:0] comb_d [0:M-1];
    
    integer i;
    
    //--------------------------------------------------------------
    // Decimation counter
    //--------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dec_cnt <= 0;
        else if (ena && fs_in) begin
            if (dec_cnt == R-1)
                dec_cnt <= 0;
            else
                dec_cnt <= dec_cnt + 1'b1;
        end
    end
    
    assign dec_ena = (dec_cnt == R-1) && fs_in && ena;
    
    //--------------------------------------------------------------
    // Integrator section (runs at input sample rate)
    //--------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < M; i = i + 1) begin
                integ[i] <= 0;
                integ_d[i] <= 0;
            end
        end else if (ena && fs_in) begin
            // First integrator stage
            integ[0] <= integ[0] + {{(OUT_WIDTH-W){1'b0}}, data_in};
            integ_d[0] <= integ[0];
            
            // Remaining integrator stages
            for (i = 1; i < M; i = i + 1) begin
                integ[i] <= integ[i] + integ_d[i-1];
                integ_d[i] <= integ[i];
            end
        end
    end
    
    //--------------------------------------------------------------
    // Comb section (runs at decimated rate)
    //--------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < M; i = i + 1) begin
                comb[i] <= 0;
                comb_d[i] <= 0;
            end
            data_out <= 0;
            valid_out <= 0;
        end else if (ena) begin
            if (dec_ena) begin
                // First comb stage
                comb[0] <= integ_d[M-1] - comb_d[0];
                comb_d[0] <= integ_d[M-1];
                
                // Remaining comb stages
                for (i = 1; i < M; i = i + 1) begin
                    comb[i] <= comb[i-1] - comb_d[i];
                    comb_d[i] <= comb[i-1];
                end
                
                // Output the last comb stage
                data_out <= comb[M-1];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
