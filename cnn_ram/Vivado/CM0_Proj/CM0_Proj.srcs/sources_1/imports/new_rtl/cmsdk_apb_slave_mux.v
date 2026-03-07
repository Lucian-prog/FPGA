//-----------------------------------------------------------------------------
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from ARM Limited.
//
//            (C) COPYRIGHT 2010-2013 ARM Limited.
//                ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from ARM Limited.
//
//      SVN Information
//
//      Checked In          : $Date: 2013-04-15 17:00:07 +0100 (Mon, 15 Apr 2013) $
//
//      Revision            : $Revision: 244029 $
//
//      Release Information : Cortex-M System Design Kit-r1p0-00rel0
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
// Abstract : APB slave multiplex
//-----------------------------------------------------------------------------
module cmsdk_apb_slave_mux #(
  // Parameters to enable/disable ports
  parameter PORT0_ENABLE  = 1,
  parameter PORT1_ENABLE  = 1,
  parameter PORT2_ENABLE  = 1,
  parameter PORT3_ENABLE  = 1,
  parameter PORT4_ENABLE  = 1,
  parameter PORT5_ENABLE  = 1,
  parameter PORT6_ENABLE  = 1,
  parameter PORT7_ENABLE  = 1,
  parameter PORT8_ENABLE  = 1,
  parameter PORT9_ENABLE  = 1)
 (
// --------------------------------------------------------------------------
// Port Definitions
// --------------------------------------------------------------------------
  input  wire  [3:0]  DECODE4BIT,
  input  wire         PSEL,

  output wire         PSEL0,
  input  wire         PREADY0,
  input  wire [31:0]  PRDATA0,
  input  wire         PSLVERR0,

  output wire         PSEL1,
  input  wire         PREADY1,
  input  wire [31:0]  PRDATA1,
  input  wire         PSLVERR1,

  output wire         PSEL2,
  input  wire         PREADY2,
  input  wire [31:0]  PRDATA2,
  input  wire         PSLVERR2,

  output wire         PSEL3,
  input  wire         PREADY3,
  input  wire [31:0]  PRDATA3,
  input  wire         PSLVERR3,

  output wire         PSEL4,
  input  wire         PREADY4,
  input  wire [31:0]  PRDATA4,
  input  wire         PSLVERR4,

  output wire         PSEL5,
  input  wire         PREADY5,
  input  wire [31:0]  PRDATA5,
  input  wire         PSLVERR5,

  output wire         PSEL6,
  input  wire         PREADY6,
  input  wire [31:0]  PRDATA6,
  input  wire         PSLVERR6,

  output wire         PSEL7,
  input  wire         PREADY7,
  input  wire [31:0]  PRDATA7,
  input  wire         PSLVERR7,

  output wire         PSEL8,
  input  wire         PREADY8,
  input  wire [31:0]  PRDATA8,
  input  wire         PSLVERR8,

  output wire         PSEL9,
  input  wire         PREADY9,
  input  wire [31:0]  PRDATA9,
  input  wire         PSLVERR9,

  output wire         PREADY,
  output wire [31:0]  PRDATA,
  output wire         PSLVERR);

  // --------------------------------------------------------------------------
  // Start of main code
  // --------------------------------------------------------------------------

  wire [9:0] en  = {  (PORT9_ENABLE  == 1), (PORT8_ENABLE  == 1),
                      (PORT7_ENABLE  == 1), (PORT6_ENABLE  == 1),
                      (PORT5_ENABLE  == 1), (PORT4_ENABLE  == 1),
                      (PORT3_ENABLE  == 1), (PORT2_ENABLE  == 1),
                      (PORT1_ENABLE  == 1), (PORT0_ENABLE  == 1) };

  wire [9:0] dec = {  (DECODE4BIT == 4'd9 ), (DECODE4BIT == 4'd8 ),
                      (DECODE4BIT == 4'd7 ), (DECODE4BIT == 4'd6 ),
                      (DECODE4BIT == 4'd5 ), (DECODE4BIT == 4'd4 ),
                      (DECODE4BIT == 4'd3 ), (DECODE4BIT == 4'd2 ),
                      (DECODE4BIT == 4'd1 ), (DECODE4BIT == 4'd0 ) };

  assign PSEL0   = PSEL & dec[ 0] & en[ 0];
  assign PSEL1   = PSEL & dec[ 1] & en[ 1];
  assign PSEL2   = PSEL & dec[ 2] & en[ 2];
  assign PSEL3   = PSEL & dec[ 3] & en[ 3];
  assign PSEL4   = PSEL & dec[ 4] & en[ 4];
  assign PSEL5   = PSEL & dec[ 5] & en[ 5];
  assign PSEL6   = PSEL & dec[ 6] & en[ 6];
  assign PSEL7   = PSEL & dec[ 7] & en[ 7];
  assign PSEL8   = PSEL & dec[ 8] & en[ 8];
  assign PSEL9   = PSEL & dec[ 9] & en[ 9];

  assign PREADY  = ~PSEL |
                   ( dec[ 0]  & (PREADY0  | ~en[ 0]) ) |
                   ( dec[ 1]  & (PREADY1  | ~en[ 1]) ) |
                   ( dec[ 2]  & (PREADY2  | ~en[ 2]) ) |
                   ( dec[ 3]  & (PREADY3  | ~en[ 3]) ) |
                   ( dec[ 4]  & (PREADY4  | ~en[ 4]) ) |
                   ( dec[ 5]  & (PREADY5  | ~en[ 5]) ) |
                   ( dec[ 6]  & (PREADY6  | ~en[ 6]) ) |
                   ( dec[ 7]  & (PREADY7  | ~en[ 7]) ) |
                   ( dec[ 8]  & (PREADY8  | ~en[ 8]) ) |
                   ( dec[ 9]  & (PREADY9  | ~en[ 9]) ) ;

  assign PSLVERR = ( PSEL0  & PSLVERR0  ) |
                   ( PSEL1  & PSLVERR1  ) |
                   ( PSEL2  & PSLVERR2  ) |
                   ( PSEL3  & PSLVERR3  ) |
                   ( PSEL4  & PSLVERR4  ) |
                   ( PSEL5  & PSLVERR5  ) |
                   ( PSEL6  & PSLVERR6  ) |
                   ( PSEL7  & PSLVERR7  ) |
                   ( PSEL8  & PSLVERR8  ) |
                   ( PSEL9  & PSLVERR9  );

  assign PRDATA  = ( {32{PSEL0 }} & PRDATA0  ) |
                   ( {32{PSEL1 }} & PRDATA1  ) |
                   ( {32{PSEL2 }} & PRDATA2  ) |
                   ( {32{PSEL3 }} & PRDATA3  ) |
                   ( {32{PSEL4 }} & PRDATA4  ) |
                   ( {32{PSEL5 }} & PRDATA5  ) |
                   ( {32{PSEL6 }} & PRDATA6  ) |
                   ( {32{PSEL7 }} & PRDATA7  ) |
                   ( {32{PSEL8 }} & PRDATA8  ) |
                   ( {32{PSEL9 }} & PRDATA9  );

endmodule
