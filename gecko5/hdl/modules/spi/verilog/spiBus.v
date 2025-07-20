module spiBus #( parameter [31:0] baseAddress = 32'h00000000,
                 parameter [7:0]  customIntructionNr = 8'd0)
               ( input wire         clock,
                                    reset,
                 
                 // The spi interface
                 output wire        spiScl,
                                    spiNCs,
                 inout wire         spiSiIo0,
                                    spiSoIo1,
                                    spiIo2,
                                    spiIo3,
                 
                 // the custom instruction interface
                 input wire [7:0]   ciN,
                 input wire [31:0]  ciDataA,
                                    ciDataB,
                 input wire         ciStart,
                                    ciCke,
                 output wire        ciDone,
                 output wire [31:0] ciResult,

                 // The bus interface
                 input wire         beginTransactionIn,
                                    endTransactionIn,
                                    readNotWriteIn,
                                    busErrorIn,
                 input wire [31:0]  addressDataIn,
                 input wire [7:0]   burstSizeIn,
                 input wire [3:0]   byteEnablesIn,
                 output wire [31:0] addressDataOut,
                 output wire        endTransactionOut,
                                    dataValidOut,
                 output reg         busErrorOut );

  /*
   *
   * Here the bus input interface is defined
   *
   */
  reg s_transactionActiveReg, s_readNotWriteReg, s_beginTransactionReg, s_endTransactionReg;
  reg [3:0]  s_byteEnablesReg;
  reg [7:0]  s_burstSizeReg;
  reg [31:0] s_busAddressReg;
  wire s_isMyTransaction = (s_transactionActiveReg == 1'b1 && s_busAddressReg[31:24] == baseAddress[31:24]) ? 1'b1 : 1'b0;  // 24 bit address range. baseAddress up to baseAddress + 0x00FF_FFFF
  wire s_busErrorOut = (s_isMyTransaction == 1'b1 && (s_byteEnablesReg != 4'hF || s_readNotWriteReg == 1'b0)) ? 1'b1 : 1'b0;
  wire s_startRead = s_isMyTransaction & s_beginTransactionReg & s_readNotWriteReg;
  
  always @(posedge clock)
    begin
      s_transactionActiveReg <= (reset == 1'b1 || s_endTransactionReg == 1'b1) ? 1'b0 : s_transactionActiveReg | beginTransactionIn;
      s_busAddressReg        <= (beginTransactionIn == 1'b1) ? addressDataIn : s_busAddressReg;
      s_readNotWriteReg      <= (beginTransactionIn == 1'b1) ? readNotWriteIn : s_readNotWriteReg;
      s_byteEnablesReg       <= (beginTransactionIn == 1'b1) ? byteEnablesIn : s_byteEnablesReg;
      s_burstSizeReg         <= (beginTransactionIn == 1'b1) ? burstSizeIn : s_burstSizeReg;
      s_beginTransactionReg  <= beginTransactionIn;
      s_endTransactionReg    <= endTransactionIn;
      busErrorOut            <= (reset == 1'b1 || endTransactionIn == 1'b1 || s_endTransactionReg == 1'b1) ? 1'b0 : s_busErrorOut;
    end

  /*
   *
   * Here the custom instruction interface is defined
   *
   */
  reg [31:0] s_ciResult, s_programData1, s_programData2, s_programData3, s_programData4, s_programData5, s_programData6;
  reg [31:0] s_programData7, s_programData8;
  reg [23:0] s_flashAddressReg;
  wire [7:0] s_manufacturingId, s_memoryType, s_memoryCap, s_statusReg0, s_statusReg1,  s_statusReg2;
  wire s_eraseErrorIndicator, s_writeErrorIndicator, s_flashBusy;
  wire s_isMyCustomInstruction = (ciN == customIntructionNr) ? ciStart & ciCke : 1'b0;
  wire s_startErase = (ciDataB[3:0] == 4'h7 && ciDataA[1] == 1'b1) ? s_isMyCustomInstruction : 1'b0;
  wire s_startProgram = (ciDataB[3:0] == 4'h7 && ciDataA[0] == 1'b1) ? s_isMyCustomInstruction : 1'b0;
  
  assign ciDone   = s_isMyCustomInstruction;
  assign ciResult = (s_isMyCustomInstruction == 1'b1) ? s_ciResult : 32'd0;
  
  always @*
    case (ciDataB[3:0])
      4'h0    : s_ciResult <= {24'd0, s_manufacturingId};
      4'h1    : s_ciResult <= {24'd0, s_memoryType};
      4'h2    : s_ciResult <= {24'd0, s_memoryCap};
      4'h3    : s_ciResult <= {24'd0, s_statusReg0};
      4'h4    : s_ciResult <= {24'd0, s_statusReg1};
      4'h5    : s_ciResult <= {24'd0, s_statusReg2};
      4'h6    : s_ciResult <= {8'd0, s_flashAddressReg};
      4'h7    : s_ciResult <= {29'd0, s_eraseErrorIndicator, s_writeErrorIndicator, s_flashBusy};
      4'h8    : s_ciResult <= s_programData1;
      4'h9    : s_ciResult <= s_programData2;
      4'hA    : s_ciResult <= s_programData3;
      4'hB    : s_ciResult <= s_programData4;
      4'hC    : s_ciResult <= s_programData5;
      4'hD    : s_ciResult <= s_programData6;
      4'hE    : s_ciResult <= s_programData7;
      default : s_ciResult <= s_programData8;
    endcase
  
  always @(posedge clock)
    begin
      s_flashAddressReg <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h16) ? ciDataA[23:0] : s_flashAddressReg;
      s_programData1    <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h18) ? ciDataA : s_programData1;
      s_programData2    <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h19) ? ciDataA : s_programData2;
      s_programData3    <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h1A) ? ciDataA : s_programData3;
      s_programData4    <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h1B) ? ciDataA : s_programData4;
      s_programData5    <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h1C) ? ciDataA : s_programData5;
      s_programData6    <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h1D) ? ciDataA : s_programData6;
      s_programData7    <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h1E) ? ciDataA : s_programData7;
      s_programData8    <= (s_isMyCustomInstruction == 1'b1 && ciDataB[5:0] == 5'h1F) ? ciDataA : s_programData8;
    end

  /*
   *
   * Here the components are mapped
   *
   */
  reg  s_endTransReg;
  wire s_resetContReadMode, s_contReadModeEnabled, s_dataOutValid, s_quadBusy, s_singleBusy;
  wire s_quadScl, s_quadNCs, s_singleScl, s_singleNCs, s_singleSiIo0;
  wire [3:0] s_quadSiIoOut, s_quadSiIoTristateEnable;
  wire [3:0] s_quadSiIoIn = {spiIo3,spiIo2,spiSoIo1,spiSiIo0};
  
  assign dataValidOut      = s_dataOutValid;
  assign endTransactionOut = s_endTransReg;
  
  always @(posedge clock) s_endTransReg <= ~reset & s_transactionActiveReg & ((s_dataOutValid & ~s_quadBusy) | (busErrorIn & ~s_busErrorOut));

  spiShiftQuad quad ( .clock(clock),
                      .reset(reset),
                      .resetContReadMode(s_resetContReadMode),
                      .start(s_startRead),
                      .flashAddress(s_busAddressReg[23:0]),
                      .nrOfWords(s_burstSizeReg),
                      .contReadModeEnabled(s_contReadModeEnabled),
                      .dataOutValid(s_dataOutValid),
                      .dataOut(addressDataOut),
                      .busyIn(s_singleBusy),
                      .busyOut(s_quadBusy),
                      .busErrorIn(busErrorIn),
                      .spiScl(s_quadScl),
                      .spiNCs(s_quadNCs),
                      .spiSiIoIn(s_quadSiIoIn),
                      .spiSiIoOut(s_quadSiIoOut),
                      .spiSiIoTristateEnable(s_quadSiIoTristateEnable));

  spiShiftSingle single ( .clock(clock),
                          .reset(reset),
                          .startErase(s_startErase),
                          .startProgram(s_startProgram),
                          .flashProgramAddress(s_flashAddressReg),
                          .programData1(s_programData1),
                          .programData2(s_programData2),
                          .programData3(s_programData3),
                          .programData4(s_programData4),
                          .programData5(s_programData5),
                          .programData6(s_programData6),
                          .programData7(s_programData7),
                          .programData8(s_programData8),
                          .flashBusy(s_flashBusy),
                          .eraseErrorIndicator(s_eraseErrorIndicator),
                          .writeErrorIndicator(s_writeErrorIndicator),
                          .resetContReadMode(s_resetContReadMode),
                          .manufacturingId(s_manufacturingId),
                          .memoryType(s_memoryType),
                          .memoryCap(s_memoryCap),
                          .statusReg0(s_statusReg0),
                          .statusReg1(s_statusReg1),
                          .statusReg2(s_statusReg2),
                          .contReadModeEnabled(s_contReadModeEnabled),
                          .busyIn(s_quadBusy),
                          .busy(s_singleBusy),
                          .spiScl(s_singleScl),
                          .spiNCs(s_singleNCs),
                          .spiSiIo0(s_singleSiIo0),
                          .spiSoIo1(spiSoIo1));

  /*
   *
   * Here the spi-interface is defined
   *
   */
  reg s_spiSclReg, s_spiNCSReg;
  reg [3:0] s_spiIoReg, s_spiTriReg;
  
  assign spiScl   = s_spiSclReg;
  assign spiNCs   = s_spiNCSReg;
  assign spiSiIo0 = (s_spiTriReg[0] == 1'b0) ? s_spiIoReg[0] : 1'bZ;
  assign spiSoIo1 = (s_spiTriReg[1] == 1'b0) ? s_spiIoReg[1] : 1'bZ;
  assign spiIo2   = (s_spiTriReg[2] == 1'b0) ? s_spiIoReg[2] : 1'bZ;
  assign spiIo3   = (s_spiTriReg[3] == 1'b0) ? s_spiIoReg[3] : 1'bZ;
  
  always @(posedge clock)
    begin
      s_spiSclReg     <= s_quadScl & s_singleScl;
      s_spiNCSReg     <= s_quadNCs & s_singleNCs;
      s_spiIoReg[0]   <= (s_singleBusy == 1'b1) ? s_singleSiIo0 : s_quadSiIoOut[0];
      s_spiIoReg[3:1] <= s_quadSiIoOut[3:1];
      s_spiTriReg     <= s_quadSiIoTristateEnable;
    end
endmodule
