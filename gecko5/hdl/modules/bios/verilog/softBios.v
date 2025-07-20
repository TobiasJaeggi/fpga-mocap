module bios ( input wire       clock,
                               reset,
                               softRomActive,
            // here is the bus interface
            input wire [31:0]  addressDataIn,
            input wire         beginTransactionIn,
                               endTransactionIn,
                               readNotWriteIn,
                               busErrorIn,
                               dataValidIn,
            input wire [3:0]   byteEnablesIn,
            input wire [7:0]   burstSizeIn,
            output reg [31:0]  addressDataOut,
            output reg         busErrorOut,
                               dataValidOut,
                               endTransactionOut );

  localparam [3:0] IDLE           = 3'd0,
                   INTERPRET      = 3'd1,
                   BURST          = 3'd2,
                   ENDTRANSACTION = 3'd3,
                   BUSERROR       = 3'd4,
                   WRITE          = 3'd5;
  
  reg [3:0]   s_stateMachineReg;
  wire [31:0] s_romData, s_ramData;
  reg [31:0]  s_addressReg;
  
  /*
   *
   * Here the outputs are defined
   *
   */
  wire s_selectSoftLow = softRomActive ^ s_addressReg[13];
  wire [31:0] s_biosData = (s_selectSoftLow == 1'b1) ? s_ramData : s_romData;
  always @(posedge clock)
    begin
      busErrorOut       <= (s_stateMachineReg == BUSERROR) ? ~endTransactionIn : 1'b0;
      endTransactionOut <= (s_stateMachineReg == ENDTRANSACTION) ? 1'b1 : 1'b0;
      dataValidOut      <= (s_stateMachineReg == BURST && endTransactionIn == 1'b0) ? 1'b1 : 1'b0;
      addressDataOut    <= (s_stateMachineReg == BURST && endTransactionIn == 1'b0) ? s_biosData : 32'd0;
    end

  /*
   *
   * Here the control related sognals are defined
   *
   */
  reg         s_endTransactionReg, s_transactionActiveReg, s_dataValidInReg, s_beginTransactionReg;
  reg [7:0]   s_burstSizeReg;
  reg [8:0]   s_burstCountReg;
  reg         s_readNotWriteReg;
  reg [10:0]  s_RomAddressReg;
  reg [31:0]  s_dataInReg;
  reg [3:0]   s_byteEnablesReg;

  wire        s_isMyBurst = (s_addressReg[31:28] == 4'hF && s_addressReg[27:14] == 0) ? s_transactionActiveReg : 1'b0;   // 14 bit address range. 0xF000_0000 up to 0xF000_3FFF
  wire [8:0]  s_burstCountNext = (s_stateMachineReg == INTERPRET && s_isMyBurst == 1'b1) ? {1'b0,s_burstSizeReg} - 9'd1 :
                                 (s_stateMachineReg == BURST) ? s_burstCountReg - 9'd1 : s_burstCountReg;
  wire [10:0] s_RomAddressNext = (s_stateMachineReg == INTERPRET && s_isMyBurst == 1'b1) ? s_addressReg[12:2] :
                                 (s_stateMachineReg == BURST) ? s_RomAddressReg + 11'd1 : s_RomAddressReg;
  
  always @(posedge clock)
    begin
      s_addressReg           <= (beginTransactionIn == 1'b1) ? addressDataIn : s_addressReg;
      s_burstSizeReg         <= (beginTransactionIn == 1'b1) ? burstSizeIn : s_burstSizeReg;
      s_readNotWriteReg      <= (beginTransactionIn == 1'b1) ? readNotWriteIn : s_readNotWriteReg;
      s_byteEnablesReg       <= (beginTransactionIn == 1'b1) ? byteEnablesIn : s_byteEnablesReg;
      s_endTransactionReg    <= ~reset & endTransactionIn;
      s_transactionActiveReg <= (reset == 1'b1 || s_endTransactionReg == 1'b1) ? 1'b0 : (beginTransactionIn == 1'b1) ? 1'b1 : s_transactionActiveReg;
      s_burstCountReg        <= (s_stateMachineReg == IDLE) ? 9'h1FF : s_burstCountNext;
      s_RomAddressReg        <= s_RomAddressNext;
      s_dataValidInReg       <= dataValidIn;
      s_dataInReg            <= (s_isMyBurst == 1'b1 && s_readNotWriteReg == 1'b0 && dataValidIn == 1'b1) ? addressDataIn : s_dataInReg;
      s_beginTransactionReg  <= beginTransactionIn;
    end
  
  /*
   *
   * Here the state machine is defined
   *
   */
  reg [3:0] s_stateMachineNext;
  
  always @*
    case (s_stateMachineReg)
      IDLE      : s_stateMachineNext <= (beginTransactionIn == 1'b1) ? INTERPRET : IDLE;
      INTERPRET : s_stateMachineNext <= (s_isMyBurst == 1'b0) ? IDLE :
                                        ((s_readNotWriteReg == 1'b0 && s_selectSoftLow == 1'b0) || (s_addressReg[1:0] != 2'd0 && s_burstSizeReg != 8'd0)) ? BUSERROR :
                                        (s_readNotWriteReg == 1'b0) ? WRITE : BURST;
      BURST     : s_stateMachineNext <= (endTransactionIn == 1'b1) ? IDLE :
                                        (s_burstCountReg[8] == 1'b1) ? ENDTRANSACTION : BURST;
      BUSERROR  : s_stateMachineNext <= (endTransactionIn == 1'b1) ? IDLE : BUSERROR;
      WRITE     : s_stateMachineNext <= (s_isMyBurst == 1'b1) ? WRITE : IDLE;
      default   : s_stateMachineNext <= IDLE;
    endcase
  
  always @(posedge clock) s_stateMachineReg <= (reset == 1'b1) ? IDLE : s_stateMachineNext;
  
  /*
   *
   * Here are the instructions
   *
   */
  reg [10:0] s_writeAddressReg;
  wire s_we1 = s_isMyBurst & ~s_readNotWriteReg & s_dataValidInReg & s_byteEnablesReg[0];
  wire s_we2 = s_isMyBurst & ~s_readNotWriteReg & s_dataValidInReg & s_byteEnablesReg[1];
  wire s_we3 = s_isMyBurst & ~s_readNotWriteReg & s_dataValidInReg & s_byteEnablesReg[2];
  wire s_we4 = s_isMyBurst & ~s_readNotWriteReg & s_dataValidInReg & s_byteEnablesReg[3];
  
  always @(posedge clock) s_writeAddressReg <= (s_beginTransactionReg == 1'b1 && s_isMyBurst == 1'b1) ? s_addressReg[12:2] :
                                               (s_isMyBurst == 1'b1 && s_readNotWriteReg == 1'b1 && s_dataValidInReg == 1'b1) ? s_writeAddressReg + 11'd1 : s_writeAddressReg;
  
  biosRom rom (.clock(clock),
               .address(s_RomAddressReg),
               .romData(s_romData));
  
  sram2048X8Dp softBios1 ( .clockA(~clock),
                           .writeEnableA(1'b0),
                           .addressA(s_RomAddressReg),
                           .dataInA(8'd0),
                           .dataOutA(s_ramData[7:0]),
                           .clockB(clock),
                           .writeEnableB(s_we1),
                           .addressB(s_writeAddressReg),
                           .dataInB(s_dataInReg[7:0]),
                           .dataOutB());
  sram2048X8Dp softBios2 ( .clockA(~clock),
                           .writeEnableA(1'b0),
                           .addressA(s_RomAddressReg),
                           .dataInA(8'd0),
                           .dataOutA(s_ramData[15:8]),
                           .clockB(clock),
                           .writeEnableB(s_we2),
                           .addressB(s_writeAddressReg),
                           .dataInB(s_dataInReg[15:8]),
                           .dataOutB());
  sram2048X8Dp softBios3 ( .clockA(~clock),
                           .writeEnableA(1'b0),
                           .addressA(s_RomAddressReg),
                           .dataInA(8'd0),
                           .dataOutA(s_ramData[23:16]),
                           .clockB(clock),
                           .writeEnableB(s_we3),
                           .addressB(s_writeAddressReg),
                           .dataInB(s_dataInReg[23:16]),
                           .dataOutB());
  sram2048X8Dp softBios4 ( .clockA(~clock),
                           .writeEnableA(1'b0),
                           .addressA(s_RomAddressReg),
                           .dataInA(8'd0),
                           .dataOutA(s_ramData[31:24]),
                           .clockB(clock),
                           .writeEnableB(s_we4),
                           .addressB(s_writeAddressReg),
                           .dataInB(s_dataInReg[31:24]),
                           .dataOutB());
endmodule
