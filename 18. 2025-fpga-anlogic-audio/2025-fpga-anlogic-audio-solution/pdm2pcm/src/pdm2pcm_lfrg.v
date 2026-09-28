//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/10/03
// Design Name: PDM to PCM Converter
// Module Name: pdm_to_pcm
// Description: PDM to PCM converter using CIC filter
//              - Generates PDM clock
//              - Samples PDM data
//              - Filters using CIC filter
//              - Scales output to desired bit width
//////////////////////////////////////////////////////////////////////////////////

module pdm_to_pcm #(
    parameter SYS_CLK_FREQ = 48_000_000,  // System clock frequency in Hz
    parameter FS_IN = 2_400_000,          // PDM sampling frequency in Hz
    parameter M = 5,                      // CIC filter stages
    parameter R = 50,                     // Decimation ratio
    parameter DW = 16,                    // Output data width
    parameter SCALE_FACTOR = 6000         // Scaling factor for CIC output
)(
    input wire clk,               // System clock
    input wire rst_n,             // Active low reset
    input wire ena,               // Enable signal
    
    output wire pdm_clk,          // PDM clock output
    input wire  pdm_dat,          // PDM data input
    
    output wire [DW-1:0] pcm_data_r,
    output wire [DW-1:0] pcm_data_l,   // PCM output data
    output wire pcm_valid            // PCM output valid
);

    // Calculate PDM clock divider
    // PDM clock toggles at FS_IN rate, so divider is for half period
    localparam DIV_COUNT = SYS_CLK_FREQ / (FS_IN * 2);
    localparam DIV_WIDTH = $clog2(DIV_COUNT);
    
    // CIC filter output width
    localparam CIC_OUT_WIDTH = 1 + M * $clog2(R);
    
    //--------------------------------------------------------------
    // PDM clock generation
    //--------------------------------------------------------------
    reg [DIV_WIDTH-1:0] clk_div_cnt;
    reg pdm_clk_reg;
    reg pdm_clk_reg_d1;  // Delayed version to detect edges
    reg fs_pulse;
    reg fs_pulse_n;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_cnt <= 0;
            pdm_clk_reg <= 0;
            pdm_clk_reg_d1 <= 0;
            fs_pulse <= 0;
            fs_pulse_n <= 0;
        end else if (ena) begin
            pdm_clk_reg_d1 <= pdm_clk_reg;
            
            if (clk_div_cnt == DIV_COUNT-1) begin
                clk_div_cnt <= 0;
                pdm_clk_reg <= ~pdm_clk_reg;
            end else begin
                clk_div_cnt <= clk_div_cnt + 1'b1;
            end
            
            // Generate pulse on rising edge of PDM clock (for right channel)
            fs_pulse <= (~pdm_clk_reg_d1) & pdm_clk_reg;
            // Generate pulse on falling edge of PDM clock (for left channel)
            fs_pulse_n <= pdm_clk_reg_d1 & (~pdm_clk_reg);
        end else begin
            pdm_clk_reg_d1 <= 0;
            fs_pulse <= 1'b0;
            fs_pulse_n <= 1'b0;
        end
    end
    
    
    assign pdm_clk = pdm_clk_reg;

    
    //--------------------------------------------------------------
    // PDM data sampling and synchronization
    // Right channel: sampled on PDM clock rising edge
    // Left channel: sampled on PDM clock falling edge
    //--------------------------------------------------------------
    reg pdm_dat_sync1;
    reg pdm_dat_sync2_r;  // Right channel sample
    reg pdm_dat_sync2_l;  // Left channel sample
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pdm_dat_sync1 <= 0;
            pdm_dat_sync2_r <= 0;
            pdm_dat_sync2_l <= 0;
        end else begin
            // First stage synchronization
            pdm_dat_sync1 <= pdm_dat;
            
            // Sample right channel on PDM clock rising edge
            if (fs_pulse) begin
                pdm_dat_sync2_r <= pdm_dat_sync1;
            end
            
            // Sample left channel on PDM clock falling edge
            if (fs_pulse_n) begin
                pdm_dat_sync2_l <= pdm_dat_sync1;
            end
        end
    end
    
    //--------------------------------------------------------------
    // CIC filter instances for right and left channels
    //--------------------------------------------------------------
    wire [CIC_OUT_WIDTH-1:0] cic_out;   // Right channel output
    wire [CIC_OUT_WIDTH-1:0] cic_outn;  // Left channel output
    wire cic_valid;   // Right channel valid
    wire cic_validn;  // Left channel valid
    
    // Right channel CIC filter (rising edge sampling)
    cic_filter #(
        .M(M),
        .R(R),
        .W(1)
    ) cic_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .data_in(pdm_dat_sync2_r),
        .fs_in(fs_pulse),
        .data_out(cic_out),
        .valid_out(cic_valid)
    );
    
    // Left channel CIC filter (falling edge sampling)
    cic_filter #(
        .M(M),
        .R(R),
        .W(1)
    ) cic_instn (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .data_in(pdm_dat_sync2_l),
        .fs_in(fs_pulse_n),
        .data_out(cic_outn),
        .valid_out(cic_validn)
    );
    
    //--------------------------------------------------------------
    // Scaling and output formatting
    //--------------------------------------------------------------
    reg [DW-1:0] pcm_data_reg;
    reg [DW-1:0] pcm_data_regn;
    reg pcm_valid_reg;
    
    // Convert CIC output to signed, scale, and truncate/extend to output width
    wire signed [CIC_OUT_WIDTH-1:0] cic_signed;
    wire signed [CIC_OUT_WIDTH-1:0] cic_signedn;
    wire signed [CIC_OUT_WIDTH-1:0] scaled_temp;
    wire signed [CIC_OUT_WIDTH-1:0] scaled_tempn;
    wire signed [DW-1:0] scaled_data;
    wire signed [DW-1:0] scaled_datan;
    
    assign cic_signed = $signed(cic_out);
    assign cic_signedn = $signed(cic_outn);
    assign scaled_temp = cic_signed / SCALE_FACTOR;
    assign scaled_tempn = cic_signedn / SCALE_FACTOR;
    
    // Saturate if necessary
    generate
        if (CIC_OUT_WIDTH > DW) begin
            // Need saturation
            wire signed [CIC_OUT_WIDTH-1:0] max_pos = (1 << (DW-1)) - 1;
            wire signed [CIC_OUT_WIDTH-1:0] max_neg = -(1 << (DW-1));
            
            assign scaled_data = (scaled_temp > max_pos) ? max_pos[DW-1:0] :
                                (scaled_temp < max_neg) ? max_neg[DW-1:0] :
                                scaled_temp[DW-1:0];
            assign scaled_datan = (scaled_tempn > max_pos) ? max_pos[DW-1:0] :
                                (scaled_tempn < max_neg) ? max_neg[DW-1:0] :
                                scaled_tempn[DW-1:0];                                
        end else begin
            // Sign extension
            assign scaled_data = scaled_temp[DW-1:0];
            assign scaled_datan = scaled_tempn[DW-1:0];
        end
    endgenerate
    
    // Delayed valid signals for IIR clock (one cycle delay to ensure data is stable)
    reg cic_valid_d1;
    reg cic_validn_d1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcm_data_reg <= 0;
            pcm_valid_reg <= 0;
            pcm_data_regn <= 0;
            cic_valid_d1 <= 0;
            cic_validn_d1 <= 0;
        end else begin
            // Delay valid signals by one clock cycle
            cic_valid_d1 <= cic_valid;
            cic_validn_d1 <= cic_validn;
            
            // Update right channel when valid
            if (cic_valid) begin
                pcm_data_reg <= scaled_data;
            end
            
            // Update left channel when valid
            if (cic_validn) begin
                pcm_data_regn <= scaled_datan;
            end
            
            // Valid signal is high when either channel has valid data
            pcm_valid_reg <= cic_valid | cic_validn;
        end
    end
    
    //--------------------------------------------------------------
    // IIR filter instances for audio preprocessing
    // Each channel uses two cascaded IIR filters
    // Using system clock with enable signals for proper timing
    //--------------------------------------------------------------
    wire signed [15:0] iir_out_r1;  // Right channel first stage output
    wire signed [15:0] iir_out_r2;  // Right channel second stage output (final)
    wire signed [15:0] iir_out_l1;  // Left channel first stage output
    wire signed [15:0] iir_out_l2;  // Left channel second stage output (final)
    
    // Delayed enable signals for cascaded IIR stages
    reg cic_valid_d2, cic_valid_d3;
    reg cic_validn_d2, cic_validn_d3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cic_valid_d2 <= 0;
            cic_valid_d3 <= 0;
            cic_validn_d2 <= 0;
            cic_validn_d3 <= 0;
        end else begin
            cic_valid_d2 <= cic_valid_d1;
            cic_valid_d3 <= cic_valid_d2;
            cic_validn_d2 <= cic_validn_d1;
            cic_validn_d3 <= cic_validn_d2;
        end
    end
    
    // Right channel IIR filter - Stage 1
    iir u_iir_r0 (
        .clk(clk),
        .rst_n(rst_n),
        .en(cic_valid_d1),
        .din(pcm_data_reg),
        .k1(1980),
        .k2(959),
        .k3(1026),
        .dout(iir_out_r1)
    );
    
    // Right channel IIR filter - Stage 2 (delayed by one cycle)
    iir u_iir_r1 (
        .clk(clk),
        .rst_n(rst_n),
        .en(cic_valid_d2),
        .din(iir_out_r1),
        .k1(1690),
        .k2(741),
        .k3(1026),
        .dout(iir_out_r2)
    );
    
    // Left channel IIR filter - Stage 1
    iir u_iir_l0 (
        .clk(clk),
        .rst_n(rst_n),
        .en(cic_validn_d1),
        .din(pcm_data_regn),
        .k1(1980),
        .k2(959),
        .k3(1026),
        .dout(iir_out_l1)
    );
    
    // Left channel IIR filter - Stage 2 (delayed by one cycle)
    iir u_iir_l1 (
        .clk(clk),
        .rst_n(rst_n),
        .en(cic_validn_d2),
        .din(iir_out_l1),
        .k1(1690),
        .k2(741),
        .k3(1026),
        .dout(iir_out_l2)
    );
    
    // DEBUG: Bypass IIR filters - output CIC data directly
    // Uncomment the following lines to bypass IIR and test CIC output
    // assign pcm_data_r = pcm_data_reg;
    // assign pcm_data_l = pcm_data_regn;
    // assign pcm_valid = pcm_valid_reg;
    
    // With IIR filters
    assign pcm_data_r = iir_out_r2;
    assign pcm_data_l = iir_out_l2;
    assign pcm_valid = cic_valid_d3 | cic_validn_d3;
    
endmodule
