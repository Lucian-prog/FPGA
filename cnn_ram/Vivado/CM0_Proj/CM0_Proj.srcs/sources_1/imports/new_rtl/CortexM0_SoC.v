
module CortexM0_SoC (
        input  wire             clk,
        input  wire             RSTn,
        inout  wire             SWDIO,  
        input  wire             SWCLK,
        output wire [3:0]       GPIO,
        output wire             TXD,
        input  wire             RXD
);

//------------------------------------------------------------------------------
// DEBUG IOBUF 
//------------------------------------------------------------------------------

wire 	SWDO;
wire 	SWDOEN;
wire 	SWDI;

assign SWDI = SWDIO;
assign SWDIO = (SWDOEN) ?  SWDO : 1'bz;

//------------------------------------------------------------------------------
// Interrupt
//------------------------------------------------------------------------------

wire [31:0] IRQ;
/*Connect the IRQ with UART*/
// assign IRQ = 32'b0;
/***************************/

wire 	RXEV;
assign RXEV = 1'b0;

//------------------------------------------------------------------------------
// AHB
//------------------------------------------------------------------------------

wire 	[31:0] 	HADDR;
wire 	[ 2:0] 	HBURST;
wire        	HMASTLOCK;
wire 	[ 3:0] 	HPROT;
wire 	[ 2:0] 	HSIZE;
wire 	[ 1:0] 	HTRANS;
wire 	[31:0] 	HWDATA;
wire        	HWRITE;
wire 	[31:0] 	HRDATA;
wire            HRESP;
wire        	HMASTER;
wire        	HREADY;

//------------------------------------------------------------------------------
// RESET AND DEBUG
//------------------------------------------------------------------------------

wire 	SYSRESETREQ;
reg 	cpuresetn;

always @(posedge clk or negedge RSTn)begin
        if (~RSTn) cpuresetn <= 1'b0;
        else if (SYSRESETREQ) cpuresetn <= 1'b0;
        else cpuresetn <= 1'b1;
end

wire 	CDBGPWRUPREQ;
reg 	CDBGPWRUPACK;

always @(posedge clk or negedge RSTn)begin
        if (~RSTn) CDBGPWRUPACK <= 1'b0;
        else CDBGPWRUPACK <= CDBGPWRUPREQ;
end

wire SLEEPHOLDACKn;
reg SLEEPHOLDREQn;

always @(posedge clk or negedge RSTn)begin
        if (~RSTn) SLEEPHOLDREQn <= 1'b1;
        else SLEEPHOLDREQn <= SLEEPHOLDACKn;
end

wire SLEEPing;
wire DMAdone;
//------------------------------------------------------------------------------
// Instantiate Cortex-M0 processor logic level
//------------------------------------------------------------------------------

cortexm0ds_logic u_logic (

        // System inputs
        .FCLK           (clk),           //FREE running clock 
        .SCLK           (clk),           //system clock
        .HCLK           (clk),           //AHB clock
        .DCLK           (clk),           //Debug clock
        .PORESETn       (RSTn),          //Power on reset
        .HRESETn        (cpuresetn),     //AHB and System reset
        .DBGRESETn      (RSTn),          //Debug Reset
        .RSTBYPASS      (1'b0),          //Reset bypass
        .SE             (1'b0),          // dummy scan enable port for synthesis

        // Power management inputs
        .SLEEPHOLDREQn  (SLEEPHOLDREQn),          // Sleep extension request from PMU
        .WICENREQ       (1'b0),          // WIC enable request from PMU
        .CDBGPWRUPACK   (CDBGPWRUPACK),  // Debug Power Up ACK from PMU
        .SLEEPING       (SLEEPing),
        .SLEEPHOLDACKn  (SLEEPHOLDACKn),
        // Power management outputs
        .CDBGPWRUPREQ   (CDBGPWRUPREQ),
        .SYSRESETREQ    (SYSRESETREQ),

        // System bus
        .HADDR          (HADDR),
        .HTRANS         (HTRANS),
        .HSIZE          (HSIZE),
        .HBURST         (HBURST),
        .HPROT          (HPROT),
        .HMASTER        (HMASTER),
        .HMASTLOCK      (HMASTLOCK),
        .HWRITE         (HWRITE),
        .HWDATA         (HWDATA),
        .HRDATA         (HRDATA),
        .HREADY         (HREADY),
        .HRESP          (HRESP),

        // Interrupts
        .IRQ            (IRQ),          //Interrupt
        .NMI            (1'b0),         //Watch dog interrupt
        .IRQLATENCY     (8'h0),
        .ECOREVNUM      (28'h0),

        // Systick
        .STCLKEN        (1'b0),
        .STCALIB        (26'h0),

        // Debug - JTAG or Serial wire
        // Inputs
        .nTRST          (1'b1),
        .SWDITMS        (SWDI),
        .SWCLKTCK       (SWCLK),
        .TDI            (1'b0),
        // Outputs
        .SWDO           (SWDO),
        .SWDOEN         (SWDOEN),

        .DBGRESTART     (1'b0),

        // Event communication
        .RXEV           (DMAdone),         // Generate event when a DMA operation completed.
        .EDBGRQ         (1'b0)             // multi-core synchronous halt request
);
//------------------------------------------------------------------------------
// AHBlite Interconncet
//------------------------------------------------------------------------------

wire    [31:0]  HADDRRev;
wire    [ 2:0]  HBURSTRev;
wire            HMASTLOCKRev;
wire    [ 3:0]  HPROTRev;
wire    [ 2:0]  HSIZERev;
wire    [ 1:0]  HTRANSRev;
wire    [31:0]  HWDATARev;
wire            HWRITERev;
wire    [31:0]  HRDATARev;
wire    [1:0]   HRESPRev;
wire            HMASTERRev;
wire            HREADYRev;

wire    [31:0]  HADDRDMA;
wire    [ 2:0]  HBURSTDMA;
wire            HMASTLOCKDMA;
wire    [ 3:0]  HPROTDMA;
wire    [ 2:0]  HSIZEDMA;
wire    [ 1:0]  HTRANSDMA;
wire    [31:0]  HWDATADMA;
wire            HWRITEDMA;
wire    [31:0]  HRDATADMA;
wire    [1:0]   HRESPDMA;
wire            HMASTERDMA;
wire            HREADYDMA;

wire            HSEL_P0;
wire    [31:0]  HADDR_P0;
wire    [2:0]   HBURST_P0;
wire            HMASTLOCK_P0;
wire    [3:0]   HPROT_P0;
wire    [1:0]   HMASTER_P0;
wire    [2:0]   HSIZE_P0;
wire    [1:0]   HTRANS_P0;
wire    [31:0]  HWDATA_P0;
wire            HWRITE_P0;
wire            HREADY_P0;
wire            HREADYOUT_P0;
wire    [31:0]  HRDATA_P0;
wire    [1:0]   HRESP_P0;

wire            HSEL_P1;
wire    [31:0]  HADDR_P1;
wire    [2:0]   HBURST_P1;
wire            HMASTLOCK_P1;
wire    [3:0]   HPROT_P1;
wire    [1:0]   HMASTER_P1;
wire    [2:0]   HSIZE_P1;
wire    [1:0]   HTRANS_P1;
wire    [31:0]  HWDATA_P1;
wire            HWRITE_P1;
wire            HREADY_P1;
wire            HREADYOUT_P1;
wire    [31:0]  HRDATA_P1;
wire    [1:0]   HRESP_P1;

wire            HSEL_P2;
wire    [31:0]  HADDR_P2;
wire    [2:0]   HBURST_P2;
wire            HMASTLOCK_P2;
wire    [3:0]   HPROT_P2;
wire    [1:0]   HMASTER_P2;
wire    [2:0]   HSIZE_P2;
wire    [1:0]   HTRANS_P2;
wire    [31:0]  HWDATA_P2;
wire            HWRITE_P2;
wire            HREADY_P2;
wire            HREADYOUT_P2;
wire    [31:0]  HRDATA_P2;
wire    [1:0]   HRESP_P2;

wire            HSEL_P3;
wire    [31:0]  HADDR_P3;
wire    [2:0]   HBURST_P3;
wire            HMASTLOCK_P3;
wire    [3:0]   HPROT_P3;
wire    [1:0]   HMASTER_P3;
wire    [2:0]   HSIZE_P3;
wire    [1:0]   HTRANS_P3;
wire    [31:0]  HWDATA_P3;
wire            HWRITE_P3;
wire            HREADY_P3;
wire            HREADYOUT_P3;
wire    [31:0]  HRDATA_P3;
wire    [1:0]   HRESP_P3;

wire            HSEL_P4;
wire    [31:0]  HADDR_P4;
wire    [2:0]   HBURST_P4;
wire            HMASTLOCK_P4;
wire    [3:0]   HPROT_P4;
wire    [1:0]   HMASTER_P4;
wire    [2:0]   HSIZE_P4;
wire    [1:0]   HTRANS_P4;
wire    [31:0]  HWDATA_P4;
wire            HWRITE_P4;
wire            HREADY_P4;
wire            HREADYOUT_P4;
wire    [31:0]  HRDATA_P4;
wire    [1:0]   HRESP_P4;

wire            HSEL_P5;
wire    [31:0]  HADDR_P5;
wire    [2:0]   HBURST_P5;
wire            HMASTLOCK_P5;
wire    [3:0]   HPROT_P5;
wire    [1:0]   HMASTER_P5;
wire    [2:0]   HSIZE_P5;
wire    [1:0]   HTRANS_P5;
wire    [31:0]  HWDATA_P5;
wire            HWRITE_P5;
wire            HREADY_P5;
wire            HREADYOUT_P5;
wire    [31:0]  HRDATA_P5;
wire    [1:0]   HRESP_P5;
//------------------------------------------------------------------------------
// AHB Bus Matrix 3slave 5master 
//------------------------------------------------------------------------------

 
AHB_BusMatrix_3x6_L1 AHB_BusMatrix_3x6_L1_inst (

    // Common AHB signals
    .HCLK               (clk),
    .HRESETn            (cpuresetn),

    // System address remapping control
    .REMAP              (4'd0),

    // Input port SI0 (inputs from M0 SYSTEM BUS)
    .HSELS0             (1'b1),
    .HADDRS0            (HADDR),
    .HTRANSS0           (HTRANS),
    .HWRITES0           (HWRITE),
    .HSIZES0            (HSIZE),
    .HBURSTS0           (HBURST),
    .HPROTS0            (HPROT),
    .HMASTERS0          (4'b0),
    .HWDATAS0           (HWDATA),
    .HMASTLOCKS0        (HMASTLOCK),
    .HREADYS0           (HREADY),
    .HAUSERS0           (32'b0),
    .HWUSERS0           (32'b0),
    .HRDATAS0           (HRDATA),
    .HREADYOUTS0        (HREADY),
    .HRESPS0            (HRESP),
    .HRUSERS0           (),

    // Input port SI1 (inputs from DMA WBUS)
    .HSELS1             (1'b1),
    .HADDRS1            (HADDRDMA),
    .HTRANSS1           (HTRANSDMA),
    .HWRITES1           (HWRITEDMA),
    .HSIZES1            (HSIZEDMA),
    .HBURSTS1           (HBURSTDMA),
    .HPROTS1            (HPROTDMA),
    .HMASTERS1          (4'b0),
    .HWDATAS1           (HWDATADMA),
    .HMASTLOCKS1        (),
    .HREADYS1           (HREADYDMA),
    .HAUSERS1           (32'b0),
    .HWUSERS1           (32'b0),
    .HRDATAS1           (HRDATADMA),
    .HREADYOUTS1        (HREADYDMA),
    .HRESPS1            (HRESPDMA),
    .HRUSERS1           (),

    // Input port SI2 (inputs from DMA RBUS)
    .HSELS2             (1'b1),
    .HADDRS2            (HADDRRev),
    .HTRANSS2           (HTRANSRev),
    .HWRITES2           (1'b0),
    .HSIZES2            (HSIZERev),
    .HBURSTS2           (HBURSTRev),
    .HPROTS2            (HPROTRev),
    .HMASTERS2          (4'b0),
    .HWDATAS2           (32'b0),
    .HMASTLOCKS2        (1'b0),
    .HREADYS2           (HREADYRev),
    .HAUSERS2           (32'b0),
    .HWUSERS2           (32'b0),
    .HRDATAS2           (HRDATARev),
    .HREADYOUTS2        (HREADYRev),
    .HRESPS2            (HRESPRev),
    .HRUSERS2           (),

    // Output port MI0 (outputs to FLASH)
    .HSELM0             (HSEL_P0),
    .HADDRM0            (HADDR_P0),
    .HTRANSM0           (HTRANS_P0),
    .HWRITEM0           (HWRITE_P0),
    .HSIZEM0            (HSIZE_P0),
    .HBURSTM0           (HBURST_P0),
    .HPROTM0            (HPROT_P0),
    .HMASTERM0          (HMASTER_P0),
    .HWDATAM0           (HWDATA_P0),
    .HMASTLOCKM0        (HMASTLOCK_P0),
    .HREADYMUXM0        (HREADY_P0),
    .HAUSERM0           (),
    .HWUSERM0           (),
    .HRDATAM0           (HRDATA_P0),
    .HREADYOUTM0        (HREADYOUT_P0),
    .HRESPM0            (HRESP_P0),
    .HRUSERM0           (32'b0),


    // Output port MI1 (outputs to RAM)
    .HSELM1             (HSEL_P1),
    .HADDRM1            (HADDR_P1),
    .HTRANSM1           (HTRANS_P1),
    .HWRITEM1           (HWRITE_P1),
    .HSIZEM1            (HSIZE_P1),
    .HBURSTM1           (HBURST_P1),
    .HPROTM1            (HPROT_P1),
    .HMASTERM1          (HMASTER_P1),
    .HWDATAM1           (HWDATA_P1),
    .HMASTLOCKM1        (HMASTLOCK_P1),
    .HREADYMUXM1        (HREADY_P1),
    .HAUSERM1           (),
    .HWUSERM1           (),
    .HRDATAM1           (HRDATA_P1),
    .HREADYOUTM1        (HREADYOUT_P1),
    .HRESPM1            (HRESP_P1),
    .HRUSERM1           (32'b0),

    // Output port MI2 (outputs to GPIO) 0x3000_0000 ~ 0x307F_FFFF
    .HSELM2             (HSEL_P2),
    .HADDRM2            (HADDR_P2),
    .HTRANSM2           (HTRANS_P2),
    .HWRITEM2           (HWRITE_P2),
    .HSIZEM2            (HSIZE_P2),
    .HBURSTM2           (HBURST_P2),
    .HPROTM2            (HPROT_P2),
    .HMASTERM2          (HMASTER_P2),
    .HWDATAM2           (HWDATA_P2),
    .HMASTLOCKM2        (HMASTLOCK_P2),
    .HREADYMUXM2        (HREADY_P2),
    .HAUSERM2           (),
    .HWUSERM2           (),
    .HRDATAM2           (HRDATA_P2),
    .HREADYOUTM2        (HREADYOUT_P2),
    .HRESPM2            (HRESP_P2),
    .HRUSERM2           (32'b0),

    // Output port MI3 (outputs to DMA) 0x3080_0000 ~ 0x30FF_FFFF
    .HSELM3             (HSEL_P3),
    .HADDRM3            (HADDR_P3),
    .HTRANSM3           (HTRANS_P3),
    .HWRITEM3           (HWRITE_P3),
    .HSIZEM3            (HSIZE_P3),
    .HBURSTM3           (HBURST_P3),
    .HPROTM3            (HPROT_P3),
    .HMASTERM3          (HMASTER_P3),
    .HWDATAM3           (HWDATA_P3),
    .HMASTLOCKM3        (HMASTLOCK_P3),
    .HREADYMUXM3        (HREADY_P3),
    .HAUSERM3           (),
    .HWUSERM3           (),
    .HRDATAM3           (HRDATA_P3),
    .HREADYOUTM3        (HREADYOUT_P3),
    .HRESPM3            (HRESP_P3),
    .HRUSERM3           (32'b0),

    // Output port MI4 (outputs to AHB2APB Bridge) 0x4000_0000 ~ 0x4FFF_FFFF
    .HSELM4             (HSEL_P4),
    .HADDRM4            (HADDR_P4),
    .HTRANSM4           (HTRANS_P4),
    .HWRITEM4           (HWRITE_P4),
    .HSIZEM4            (HSIZE_P4),
    .HBURSTM4           (HBURST_P4),
    .HPROTM4            (HPROT_P4),
    .HMASTERM4          (HMASTER_P4),
    .HWDATAM4           (HWDATA_P4),
    .HMASTLOCKM4        (HMASTLOCK_P4),
    .HREADYMUXM4        (HREADY_P4),
    .HAUSERM4           (),
    .HWUSERM4           (),
    .HRDATAM4           (HRDATA_P4),
    .HREADYOUTM4        (HREADYOUT_P4),
    .HRESPM4            (HRESP_P4),
    .HRUSERM4           (32'b0),

    // Output port MI4 (outputs to default slave) 0x6000_0000 ~ 0x6FFF_FFFF
    .HSELM5             (HSEL_P5),
    .HADDRM5            (HADDR_P5),
    .HTRANSM5           (HTRANS_P5),
    .HWRITEM5           (HWRITE_P5),
    .HSIZEM5            (HSIZE_P5),
    .HBURSTM5           (HBURST_P5),
    .HPROTM5            (HPROT_P5),
    .HMASTERM5          (HMASTER_P5),
    .HWDATAM5           (HWDATA_P5),
    .HMASTLOCKM5        (HMASTLOCK_P5),
    .HREADYMUXM5        (HREADY_P5),
    .HAUSERM5           (),
    .HWUSERM5           (),
    .HRDATAM5           (HRDATA_P5),
    .HREADYOUTM5        (HREADYOUT_P5),
    .HRESPM5            (HRESP_P5),
    .HRUSERM5           (32'b0),

    // Scan test dummy signals; not connected until scan insertion
    .SCANOUTHCLK        (),       // Scan Chain Output
    // Scan test dummy signals; not connected until scan insertion
    .SCANENABLE         (1'b0),   // Scan Test Mode Enable
    .SCANINHCLK         (1'b0)    // Scan Chain Input
    );


wire [31:0] DMAdst;
wire [31:0] DMAsrc;
wire [1:0]  DMAsize;
wire [31:0] DMAlen;
wire        DMAstart;

AHB_DMAC_Config AHB_DMAC_Config_0(
    //AHB SLAVE
    .HCLK       (clk),    
    .HRESETn    (cpuresetn), 
    .HSEL       (HSEL_P3),    
    .HADDR      (HADDR_P3),   
    .HTRANS     (HTRANS_P3),  
    .HSIZE      (HSIZE_P3),   
    .HPROT      (HPROT_P3),   
    .HWRITE     (HWRITE_P3),  
    .HWDATA     (HWDATA_P3),    
    .HREADY     (HREADY_P3),
    .HREADYOUT  (HREADYOUT_P3), 
    .HRDATA     (HRDATA_P3),  
    .HRESP      (HRESP_P3),
    .HMASTERC   (HMASTER_P3),

    .DMAdone    (DMAdone),
    .SLEEPing   (SLEEPing),
    .DMAstart   (DMAstart),
    .DMAsrc     (DMAsrc),
    .DMAdst     (DMAdst),
    .DMAsize    (DMAsize),
    .DMAlen     (DMAlen),
    .HMASTERSEL ()
);

AHB_DMAC AHB_DMAC(
    .HCLK       (clk),
    .HRESETn    (cpuresetn),
    .HADDRD     (HADDRDMA), 
    .HTRANSD    (HTRANSDMA), 
    .HSIZED     (HSIZEDMA), 
    .HBURSTD    (HBURSTDMA), 
    .HPROTD     (HPROTDMA), 
    .HWRITED    (HWRITEDMA), 
    .HWDATAD    (HWDATADMA), 
    .HRDATAD    (HRDATADMA),
    .HREADYD    (HREADYDMA),
    .HRESPD     (HRESPDMA),
    .DMAstart   (DMAstart),
    .DMAdone    (DMAdone),
    .DMAsrc     (DMAsrc),
    .DMAdst     (DMAdst),
    .DMAsize    (DMAsize),
    .DMAlen     (DMAlen)
);

//------------------------------------------------------------------------------
// AHB FLASH
//------------------------------------------------------------------------------
cmsdk_ahb_ram #(
  .MEM_TYPE             (2),                 // Memory Type : Default to behavioral memory
  .AW                   (16),                // Address width
  .filename             ("C:/Users/SYG/Desktop/SoC+DMA/Keil_proj/USER/WirelessMCU.hex"),
  .WS_N                 (0),                 // First access wait state
  .WS_S                 (0)                  // Subsequent access wait state
 )
FLASH(
  .HCLK                 (clk),               // Clock
  .HRESETn              (cpuresetn),         // Reset
  .HSEL                 (HSEL_P0),      // Device select
  .HADDR                (HADDR_P0),     // Address
  .HTRANS               (HTRANS_P0),    // Transfer control
  .HSIZE                (HSIZE_P0),     // Transfer size
  .HWRITE               (HWRITE_P0),    // Write control
  .HWDATA               (HWDATA_P0),    // Write data
  .HREADY               (HREADY_P0),    // Transfer phase done
  // AHB Outputs
  .HREADYOUT            (HREADYOUT_P0), // Device ready
  .HRDATA               (HRDATA_P0),    // Read data output
  .HRESP                (HRESP_P0[0])
);

assign  HRESP_P0[1]    =   1'b0;

//------------------------------------------------------------------------------
// AHB SRAM
//------------------------------------------------------------------------------
cmsdk_ahb_ram #(
  .MEM_TYPE             (2),                // Memory Type : Default to behavioral memory
  .AW                   (16),               // Address width
  .filename             ("C:/Users/SYG/Desktop/SoC+DMA/Keil_proj/USER/WirelessMCU.hex"),
  .WS_N                 (0),                // First access wait state
  .WS_S                 (0)                 // Subsequent access wait state
 )
SRAM(
  .HCLK                 (clk),              // Clock
  .HRESETn              (cpuresetn),        // Reset
  .HSEL                 (HSEL_P1),     // Device select
  .HADDR                (HADDR_P1),    // Address
  .HTRANS               (HTRANS_P1),   // Transfer control
  .HSIZE                (HSIZE_P1),    // Transfer size
  .HWRITE               (HWRITE_P1),   // Write control
  .HWDATA               (HWDATA_P1),   // Write data
  .HREADY               (HREADY_P1),   // Transfer phase done
  // AHB Outputs
  .HREADYOUT            (HREADYOUT_P1),// Device ready
  .HRDATA               (HRDATA_P1),   // Read data output
  .HRESP                (HRESP_P1[0])
);

assign  HRESP_P1[1]    =   1'b0;
//------------------------------------------------------------------------------
// AHB2APB Bridge
//------------------------------------------------------------------------------
//
wire 	[15:0] 	PADDR;
wire 			PWRITE;
wire 	[31:0] 	PWDATA;
wire 			PENABLE;
wire    [31:0]  apb_subsystem_intr;

cmsdk_apb_subsystem #(

    .INCLUDE_IRQ_SYNCHRONIZER   (0),
    .INCLUDE_APB_TIMER0         (1),  // Include simple timer #0
    .INCLUDE_APB_TIMER1         (1),  // Include simple timer #1
    .INCLUDE_APB_DUALTIMER0     (1),  // Include dual timer module
    .APB_EXT_PORT3_ENABLE       (0),
    .INCLUDE_APB_UART0          (1),  // Include simple UART #0
    .INCLUDE_APB_UART1          (1),  // Include simple UART #1
    .APB_EXT_PORT6_ENABLE       (0),
    .APB_EXT_PORT7_ENABLE       (0),
    .INCLUDE_APB_WATCHDOG       (1),  // Include APB watchdog module
    .APB_EXT_PORT9_ENABLE       (0),   
    .BE                         (0)
    )APB_Subsystem(
    .HCLK                       (clk),
    .HRESETn                    (cpuresetn),
    .HSEL                       (HSEL_P4),
    .HADDR                      (HADDR_P4),
    .HTRANS                     (HTRANS_P4),
    .HWRITE                     (HWRITE_P4),
    .HSIZE                      (HSIZE_P4),
    .HPROT                      (HPROT_P4),
    .HREADY                     (HREADY_P4),
    .HWDATA                     (HWDATA_P4),
    .HREADYOUT                  (HREADYOUT_P4),
    .HRDATA                     (HRDATA_P4),
    .HRESP                      (HRESP_P4[0]),

    .PCLK                       (clk), // Peripheral clock
    .PCLKG                      (clk), // Gate PCLK for bus interface only
    .PCLKEN                     (1'b1), // Clock divider for AHB to APB bridge
    .PRESETn                    (cpuresetn), // APB reset
    .PADDR                      (PADDR),
    .PWRITE                     (PWRITE),
    .PWDATA                     (PWDATA),
    .PENABLE                    (PENABLE),

    .ext3_psel                  (dma_psel),
    .ext3_prdata                (dma_prdata),
    .ext3_pready                (dma_pready),
    .ext3_pslverr               (dma_pslverr),

    .ext6_psel                  (),
    .ext6_prdata                (0),
    .ext6_pready                (0),
    .ext6_pslverr               (0),

    .ext7_psel                  (),
    .ext7_prdata                (0),
    .ext7_pready                (0),
    .ext7_pslverr               (0),

    .ext9_psel                  (),
    .ext9_prdata                (0),
    .ext9_pready                (0),
    .ext9_pslverr               (0),

    .APBACTIVE                  (),

    // Peripherals
    // UART
    .uart0_rxd                  (RXD),
    .uart0_txd                  (TXD),
    .uart0_txen                 (),

    // Interrupt outputs
    .apbsubsys_interrupt        (apb_subsystem_intr),
    .watchdog_interrupt         (),
    .watchdog_reset             ()
);

assign  HRESP_P3[1]    =   1'b0;

//------------------------------------------------------------------------------
// AHB GPIO
//------------------------------------------------------------------------------
wire   [15:0]     p0_in;                        // GPIO 0 inputs
wire   [15:0]     p0_out;                       // GPIO 0 outputs
wire   [15:0]     p0_outen;                     // GPIO 0 output enables
wire   [15:0]     p0_altfunc;                   // GPIO 0 alternate function (pin mux)
 
assign GPIO  = p0_outen[3:0] & p0_out[3:0];
 
 cmsdk_ahb_gpio 
 #(
   .ALTERNATE_FUNC_MASK     (16'h0000),         // = 16'hFFFF,
   .ALTERNATE_FUNC_DEFAULT  (16'h0000),         // = 16'h0000,
   .BE                      (0)                 // = 0
  )
  AHB_GPIO (// AHB Inputs
   .HCLK                    (clk),              // system bus clock
   .HRESETn                 (cpuresetn),        // system bus reset
   .FCLK                    (clk),              // system bus clock
   .HSEL                    (HSEL_P2),          // AHB peripheral select
   .HREADY                  (HREADY_P2),        // AHB ready input
   .HTRANS                  (HTRANS_P2),        // AHB transfer type
   .HSIZE                   (HSIZE_P2),         // AHB hsize
   .HWRITE                  (HWRITE_P2),        // AHB hwrite
   .HADDR                   (HADDR_P2),         // AHB address bus
   .HWDATA                  (HWDATA_P2),        // AHB write data bus

   .ECOREVNUM               (),                 // Engineering-change-order revision bits

   .PORTIN                  (16'd0),            // GPIO Interface input

   // AHB Outputs
   .HREADYOUT               (HREADYOUT_P2),// AHB ready output to S->M mux
   .HRESP                   (HRESP_P2[0]), // AHB response
   .HRDATA                  (HRDATA_P2),

   .PORTOUT                 (p0_out),           // GPIO output
   .PORTEN                  (p0_outen),         // GPIO output enable
   .PORTFUNC                (),                 // Alternate function control

   .GPIOINT                 (),                 // Interrupt output for each pin
   .COMBINT                 ()
   );

 assign  HRESP_P2[1]    =   1'b0;

 cmsdk_ahb_eg_slave #(
  // Parameter for address width
  .ADDRWIDTH(12)
 )
 AHB_CNN(
  .HCLK         (clk),       // Clock
  .HRESETn      (cpuresetn),    // Reset

  .ECOREVNUM    (), // Engineering-change-order revision bits

  // AHB connection to master
  .HSELS        (HSEL_P5),
  .HADDRS       (HADDR_P5),
  .HTRANSS      (HTRANS_P5),
  .HSIZES       (HSIZE_P5),
  .HWRITES      (HWRITE_P5),
  .HREADYS      (HREADY_P5),
  .HWDATAS      (HWDATA_P5),

  .HREADYOUTS   (HREADYOUT_P5),
  .HRESPS       (HRESP_P5[0]),
  .HRDATAS      (HRDATA_P5)
 );

 assign  HRESP_P5[1]    =   1'b0;
//------------------------------------------------------------------------------
// INTERRUPT 
//------------------------------------------------------------------------------

//assign  IRQ = {237'b0,TXOVRINT|RXOVRINT,RXINT,TXINT};
assign  IRQ = {208'b0,apb_subsystem_intr[31:0]};



endmodule
