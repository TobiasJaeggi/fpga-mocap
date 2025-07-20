module bios ( input wire       clock,
                               reset,
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
                   BUSERROR       = 3'd4;
  
  reg [3:0]   s_stateMachineReg;
  wire [31:0] s_romData;
  reg [31:0]  s_addressReg;
  
  /*
   *
   * Here the outputs are defined
   *
   */
  always @(posedge clock)
    begin
      busErrorOut       <= (s_stateMachineReg == BUSERROR) ? ~endTransactionIn : 1'b0;
      endTransactionOut <= (s_stateMachineReg == ENDTRANSACTION) ? 1'b1 : 1'b0;
      dataValidOut      <= (s_stateMachineReg == BURST && endTransactionIn == 1'b0) ? 1'b1 : 1'b0;
      addressDataOut    <= (s_stateMachineReg == BURST && endTransactionIn == 1'b0) ? s_romData : 32'd0;
    end

  /*
   *
   * Here the control related sognals are defined
   *
   */
  reg         s_endTransactionReg, s_transactionActiveReg;
  reg [7:0]   s_burstSizeReg;
  reg [8:0]   s_burstCountReg;
  reg         s_readNotWriteReg;
  reg [10:0]  s_RomAddressReg;
  reg [3:0]   s_byteEnablesReg;

  wire        s_isMyBurst = (s_addressReg[31:28] == 4'hF && s_addressReg[27:13] == 0) ? s_transactionActiveReg : 1'b0;
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
                                        (s_readNotWriteReg == 1'b0 || (s_addressReg[1:0] != 2'd0 && s_burstSizeReg != 8'd0)) ? BUSERROR : BURST;
      BURST     : s_stateMachineNext <= (endTransactionIn == 1'b1) ? IDLE :
                                        (s_burstCountReg[8] == 1'b1) ? ENDTRANSACTION : BURST;
      BUSERROR  : s_stateMachineNext <= (endTransactionIn == 1'b1) ? IDLE : BUSERROR;
      default   : s_stateMachineNext <= IDLE;
    endcase
  
  always @(posedge clock) s_stateMachineReg <= (reset == 1'b1) ? IDLE : s_stateMachineNext;
  
  /*
   *
   * Here are the instructions
   *
   */
  
  
  biosRom rom (.clock(clock),
               .address(s_RomAddressReg),
               .romData(s_romData));
endmodule
