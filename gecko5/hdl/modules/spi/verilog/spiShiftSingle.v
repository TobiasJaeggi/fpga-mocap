module spiShiftSingle ( input wire         clock,
                                           reset,
                                           startErase,
                                           startProgram,
                        input wire [23:0]  flashProgramAddress,
                        input wire [31:0]  programData1,
                                           programData2,
                                           programData3,
                                           programData4,
                                           programData5,
                                           programData6,
                                           programData7,
                                           programData8,
                        output wire        flashBusy,
                                           eraseErrorIndicator,
                                           writeErrorIndicator,
                                           resetContReadMode,
                        output wire [7:0]  manufacturingId,
                                           memoryType,
                                           memoryCap,
                                           statusReg0,
                                           statusReg1,
                                           statusReg2,
                        input wire         contReadModeEnabled,
                                           busyIn,
                        output wire        busy,
                        
                        // here the flash-chip interface is defined
                        output wire        spiScl,
                                           spiNCs,
                                           spiSiIo0,
                        input wire         spiSoIo1 );

  localparam [5:0] LOADJEDEC = 6'd0, READJDEC = 6'd1, STOREJDEC = 6'd2, IDLE = 6'd3,
                   INITSTATUS1 = 6'd4, READSTATUS1 = 6'd5, WRITESTATUS1 = 6'd6,
                   INITSTATUS2 = 6'd7, READSTATUS2 = 6'd8, WRITESTATUS2 = 6'd9,
                   INITSTATUS3 = 6'd10, READSTATUS3 = 6'd11, WRITESTATUS3 = 6'd12,
                   INITWEENA = 6'd13, WAITWEENA = 6'd14, WEENADONE = 6'd15,
                   INITWESTATUS = 6'd16, WAITWESTATUS = 6'd17, WESTATUSDONE = 6'd18,
                   INITSECTORERASE = 6'd19, WAITSECTORERASE = 6'd20,
                   INITWRITE = 6'd21, WAITWRITECMD = 6'd22, WAITWRITEBYTE1 = 6'd23,
                   WAITWRITEBYTE2 = 6'd24, WAITWRITEBYTE3 = 6'd25, WAITWRITEBYTE4 = 6'd26,
                   WAITWRITEBYTE5 = 6'd27, WAITWRITEBYTE6 = 6'd28, WAITWRITEBYTE7 = 6'd29,
                   WAITWRITEBYTE8 = 6'd30, RESCONTREAD = 6'd31, WAITCONTREAD = 6'd32;
  localparam [5:0] RES = 6'd0, INITRESCONTREAD = 6'd1, WAITRESCONTREAD = 6'd2, READJEDECID = 6'd3,
                   WAITJEDECID = 6'd4, INITSTATUSWRITE = 6'd5, WAITINITSTATUSWRITE = 6'd6,
                   WRITESTATUSREGS = 6'd7, WAITWRITESTATUSREGS = 6'd8, INITBUSYWAIT1 = 6'd9,
                   WAITBUSYWAIT1 = 6'd10, INITSTATR2 = 6'd11, WAITSTATUS2 = 6'd12, INITSTATR3 = 6'd13,
                   WAITSTATUS3 = 6'd14, NOP = 6'd15, INITERASE0 = 6'd16, WAITINITERASE0 = 6'd17,
                   INITERASE1 = 6'd18, WAITINITERASE1 = 6'd19, INITERASE2 = 6'd20, WAITINITERASE2 = 6'd21,
                   INITERASE3 = 6'd22, WAITINITERASE3 = 6'd23, ERASEERROR = 6'd24, INITWRITE0 = 6'd25,
                   WAITINITWRITE0 = 6'd26, INITWRITE1 = 6'd27, WAITINITWRITE1 = 6'd28, 
                   INITWRITE2 = 6'd29, WAITINITWRITE2 = 6'd30, INITWRITE3 = 6'd31, WAITINITWRITE3 = 6'd32,
                   WRITEERROR = 6'd33;

  reg[5:0] s_stateReg, s_stateNext, s_cntrlReg, s_cntrlNext;
  reg[32:0] s_shiftReg;
  reg s_sclReg, s_activeReg;
  
  /*
   *
   * Here we define the user registers
   *
   */
  reg s_chipPresentReg;
  reg [7:0] s_manufacturingIdReg, s_memoryTypeReg, s_memoryCapReg;
  reg [7:0] s_status0Reg, s_status1Reg, s_status2Reg;
  reg       s_eraseErrorIndicatorReg, s_writeErrorIndicatorReg;
  wire s_chipPresentNext = (s_stateReg != STOREJDEC) ? s_chipPresentReg :
                           (s_shiftReg[23:0] == 24'hFFFFFF) ? 1'b0 : 1'b1;

  assign manufacturingId     = s_manufacturingIdReg;
  assign memoryType          = s_memoryTypeReg;
  assign memoryCap           = s_memoryCapReg;
  assign statusReg0          = s_status0Reg;
  assign statusReg1          = s_status1Reg;
  assign statusReg2          = s_status2Reg;
  assign eraseErrorIndicator = s_eraseErrorIndicatorReg;
  assign writeErrorIndicator = s_writeErrorIndicatorReg;
  
  always @(posedge clock)
    begin
      s_chipPresentReg         <= (reset == 1'b1) ? 1'b0 : s_chipPresentNext;
      s_manufacturingIdReg     <= (reset == 1'b1) ? 8'd0 : (s_stateReg == STOREJDEC) ? s_shiftReg[23:16] : s_manufacturingIdReg;
      s_memoryTypeReg          <= (reset == 1'b1) ? 8'd0 : (s_stateReg == STOREJDEC) ? s_shiftReg[15:8] : s_memoryTypeReg;
      s_memoryCapReg           <= (reset == 1'b1) ? 8'd0 : (s_stateReg == STOREJDEC) ? s_shiftReg[7:0] : s_memoryCapReg;
      s_status0Reg             <= (reset == 1'b1) ? 8'd0 : (s_stateReg == WRITESTATUS1) ? s_shiftReg[7:0] : s_status0Reg;
      s_status1Reg             <= (reset == 1'b1) ? 8'd0 : (s_stateReg == WRITESTATUS2) ? s_shiftReg[7:0] : s_status1Reg;
      s_status2Reg             <= (reset == 1'b1) ? 8'd0 : (s_stateReg == WRITESTATUS3) ? s_shiftReg[7:0] : s_status2Reg;
      s_eraseErrorIndicatorReg <= (reset == 1'b1 || s_cntrlReg == INITERASE0) ? 1'b0 : (s_cntrlReg == ERASEERROR) ? 1'b1 : s_eraseErrorIndicatorReg;
      s_writeErrorIndicatorReg <= (reset == 1'b1 || s_cntrlReg == INITWRITE0) ? 1'b0 : (s_cntrlReg == WRITEERROR) ? 1'b1 : s_writeErrorIndicatorReg;
    end

  /*
   *
   * here the sector erase and program signals are defined
   *
   */
  reg s_erasePendingReg, s_writePendingReg;
  
  wire s_startErase = s_erasePendingReg & ~busyIn;
  wire s_startWrite = s_writePendingReg & ~busyIn;
  wire s_erasePendingNext = (startErase == 1'b1) ? 1'b1 : (s_cntrlReg == INITERASE1) ? 1'b0 : s_erasePendingReg;
  wire s_writePendingNext = (startProgram == 1'b1) ? 1'b1 : (s_cntrlReg == INITWRITE1) ? 1'b0 : s_writePendingReg;
  
  always @(posedge clock)
    begin
      s_erasePendingReg <= (reset == 1'b1) ? 1'b0 : s_erasePendingNext;
      s_writePendingReg <= (reset == 1'b1) ? 1'b0 : s_writePendingNext;
    end
  
  /*
   *
   * here some control signals and the bit counter are defined
   *
   */
  reg[5:0] s_bitCountReg;
  
  wire s_shiftDone = s_bitCountReg[5] & s_sclReg;
  wire s_loadByte1 = (s_stateReg == WAITWRITECMD) ? s_shiftDone : 1'b0;
  wire s_loadByte2 = (s_stateReg == WAITWRITEBYTE1) ? s_shiftDone : 1'b0;
  wire s_loadByte3 = (s_stateReg == WAITWRITEBYTE2) ? s_shiftDone : 1'b0;
  wire s_loadByte4 = (s_stateReg == WAITWRITEBYTE3) ? s_shiftDone : 1'b0;
  wire s_loadByte5 = (s_stateReg == WAITWRITEBYTE4) ? s_shiftDone : 1'b0;
  wire s_loadByte6 = (s_stateReg == WAITWRITEBYTE5) ? s_shiftDone : 1'b0;
  wire s_loadByte7 = (s_stateReg == WAITWRITEBYTE6) ? s_shiftDone : 1'b0;
  wire s_loadByte8 = (s_stateReg == WAITWRITEBYTE7) ? s_shiftDone : 1'b0;
  wire [5:0] s_bitCountNext = (s_stateReg == LOADJEDEC || s_stateReg == INITWESTATUS || s_stateReg == INITSECTORERASE || s_stateReg == INITWRITE) ? 6'd31 :
                              (s_loadByte1 == 1'b1 || s_loadByte2 == 1'b1 || s_loadByte3 == 1'b1 || s_loadByte4 == 1'b1 ||
                               s_loadByte5 == 1'b1 || s_loadByte6 == 1'b1 || s_loadByte7 == 1'b1 || s_loadByte8 == 1'b1) ? 6'd30 :
                              (s_stateReg == INITSTATUS1 || s_stateReg == INITSTATUS2 || s_stateReg == INITSTATUS3 || s_stateReg == RESCONTREAD) ? 6'd15 :
                              (s_stateReg == INITWEENA) ? 6'd7 :
                              (s_activeReg == 1'b1 && s_sclReg == 1'b1 && s_bitCountReg[5] == 1'b0) ? s_bitCountReg - 6'd1 : s_bitCountReg;
  
  always @(posedge clock) s_bitCountReg <= (reset == 1'b1) ? 6'b100000 : s_bitCountNext;

  /*
   *
   * In this section the active and serial clock are defined
   *
   */
  wire s_activeNext = (s_stateReg == RESCONTREAD || s_stateReg == LOADJEDEC || s_stateReg == INITSTATUS1 ||
                       s_stateReg == INITSTATUS2 || s_stateReg == INITSTATUS3 || s_stateReg == INITWESTATUS ||
                       s_stateReg == INITWEENA || s_stateReg == INITSECTORERASE ||  s_stateReg == INITWRITE ||
                       s_loadByte1 == 1'b1 || s_loadByte2 == 1'b1 || s_loadByte3 == 1'b1 || s_loadByte4 == 1'b1 ||
                       s_loadByte5 == 1'b1 || s_loadByte6 == 1'b1 || s_loadByte7 == 1'b1 || s_loadByte8 == 1'b1) ? 1'b1 :
                      (s_shiftDone == 1'b1) ? 1'b0 : s_activeReg;
  wire s_sclNext = (s_activeReg == 1'b0 || s_activeNext == 1'b0) ? 1'b1 : ~s_sclReg;
  
  always @(posedge clock)
    begin
      s_sclReg    <= (reset == 1'b1) ? 1'b1 : s_sclNext;
      s_activeReg <= (reset == 1'b1) ? 1'b0 : s_activeNext;
    end

  /*
   *
   * Here the shift register is defined
   *
   *
   */
  wire [32:0] s_shiftNext = (s_stateReg == RESCONTREAD) ? 33'hFFFF0000 :
                            (s_stateReg == LOADJEDEC) ? 33'h9F000000:
                            (s_stateReg == INITSTATUS1) ? 33'h05000000 :
                            (s_stateReg == INITSTATUS2) ? 33'h35000000 :
                            (s_stateReg == INITSTATUS3) ? 33'h33000000 :
                            (s_stateReg == INITWESTATUS) ? `ifdef GECKO5Education 33'h01400002 `else 33'h01000670 `endif:
                            (s_stateReg == INITWEENA) ? 33'h06000000 :
                            (s_stateReg == INITSECTORERASE) ? {9'h20,flashProgramAddress} :
                            (s_stateReg == INITWRITE) ? {9'h2,flashProgramAddress} :
                            (s_loadByte1 == 1'b1) ? {programData1[7:0],programData1[15:8],programData1[23:16],programData1[31:24], 1'b0} :
                            (s_loadByte2 == 1'b1) ? {programData2[7:0],programData2[15:8],programData2[23:16],programData2[31:24], 1'b0} :
                            (s_loadByte3 == 1'b1) ? {programData3[7:0],programData3[15:8],programData3[23:16],programData3[31:24], 1'b0} :
                            (s_loadByte4 == 1'b1) ? {programData4[7:0],programData4[15:8],programData4[23:16],programData4[31:24], 1'b0} :
                            (s_loadByte5 == 1'b1) ? {programData5[7:0],programData5[15:8],programData5[23:16],programData5[31:24], 1'b0} :
                            (s_loadByte6 == 1'b1) ? {programData6[7:0],programData6[15:8],programData6[23:16],programData6[31:24], 1'b0} :
                            (s_loadByte7 == 1'b1) ? {programData7[7:0],programData7[15:8],programData7[23:16],programData7[31:24], 1'b0} :
                            (s_loadByte8 == 1'b1) ? {programData8[7:0],programData8[15:8],programData8[23:16],programData8[31:24], 1'b0} :
                            (s_activeReg == 1'b1 && s_sclReg == 1'b1) ? {s_shiftReg[31:0],spiSoIo1} : s_shiftReg;

  always @(posedge clock) s_shiftReg <= (reset == 1'b1) ? 33'd0 : s_shiftNext;

  /*
   *
   * Here the control state machine is defined
   *
   */
  
  always @*
    case (s_cntrlReg)
      NOP                 : s_cntrlNext <= (s_startErase == 1'b1 && contReadModeEnabled == 1'b1) ? INITERASE0 :
                                           (s_startErase == 1'b1) ? INITERASE1 :
                                           (s_startWrite == 1'b1 && contReadModeEnabled == 1'b1) ? INITWRITE0 :
                                           (s_startWrite == 1'b1) ? INITWRITE1 : NOP;
      RES                 : s_cntrlNext <= INITRESCONTREAD;
      INITRESCONTREAD     : s_cntrlNext <= WAITRESCONTREAD;
      WAITRESCONTREAD     : s_cntrlNext <= (s_stateReg == IDLE) ? READJEDECID : WAITRESCONTREAD;
      READJEDECID         : s_cntrlNext <= WAITJEDECID;
      WAITJEDECID         : s_cntrlNext <= (s_stateReg == IDLE) ? INITSTATUSWRITE : WAITJEDECID;
      INITSTATUSWRITE     : s_cntrlNext <= WAITINITSTATUSWRITE;
      WAITINITSTATUSWRITE : s_cntrlNext <= (s_stateReg == IDLE) ? WRITESTATUSREGS : WAITINITSTATUSWRITE;
      WRITESTATUSREGS     : s_cntrlNext <= WAITWRITESTATUSREGS;
      WAITWRITESTATUSREGS : s_cntrlNext <= (s_stateReg == IDLE) ? INITBUSYWAIT1 : WAITWRITESTATUSREGS;
      INITBUSYWAIT1       : s_cntrlNext <= WAITBUSYWAIT1;
      WAITBUSYWAIT1       : s_cntrlNext <= (s_stateReg == IDLE && s_status0Reg[0] == 1'b1 && s_chipPresentReg == 1'b1) ? INITBUSYWAIT1 :
                                           (s_stateReg == IDLE) ? `ifdef GECKO5Education NOP `else INITSTATR2 `endif : WAITBUSYWAIT1;
      INITSTATR2          : s_cntrlNext <= WAITSTATUS2;
      WAITSTATUS2         : s_cntrlNext <= (s_stateReg == IDLE) ? INITSTATR3 : WAITSTATUS2;
      INITSTATR3          : s_cntrlNext <= WAITSTATUS3;
      WAITSTATUS3         : s_cntrlNext <= (s_stateReg == IDLE) ? NOP : WAITSTATUS3;
      INITERASE0          : s_cntrlNext <= WAITINITERASE0;
      WAITINITERASE0      : s_cntrlNext <= (s_stateReg == IDLE) ? INITERASE1 : WAITINITERASE0;
      INITERASE1          : s_cntrlNext <= WAITINITERASE1;
      WAITINITERASE1      : s_cntrlNext <= (s_stateReg == IDLE) ? INITERASE2 : WAITINITERASE1;
      INITERASE2          : s_cntrlNext <= WAITINITERASE2;
      WAITINITERASE2      : s_cntrlNext <= (s_stateReg == IDLE && s_status0Reg[0] == 1'b1) ? INITERASE2 :
                                           (s_stateReg == IDLE && s_status0Reg[1] == 1'b1) ? INITERASE3 :
                                           (s_stateReg == IDLE) ? ERASEERROR : WAITINITERASE2;
      INITERASE3          : s_cntrlNext <= WAITINITERASE3;
      WAITINITERASE3      : s_cntrlNext <= (s_stateReg == IDLE) ? INITBUSYWAIT1 : WAITINITERASE3;
      INITWRITE0          : s_cntrlNext <= WAITINITWRITE0;
      WAITINITWRITE0      : s_cntrlNext <= (s_stateReg == IDLE) ? INITWRITE1 : WAITINITWRITE0;
      INITWRITE1          : s_cntrlNext <= WAITINITWRITE1;
      WAITINITWRITE1      : s_cntrlNext <= (s_stateReg == IDLE) ? INITWRITE2 : WAITINITWRITE1;
      INITWRITE2          : s_cntrlNext <= WAITINITWRITE2;
      WAITINITWRITE2      : s_cntrlNext <= (s_stateReg == IDLE && s_status0Reg[0] == 1'b1) ? INITWRITE2 :
                                           (s_stateReg == IDLE && s_status0Reg[1] == 1'b1) ? INITWRITE3 :
                                           (s_stateReg == IDLE) ? WRITEERROR : WAITINITWRITE2;
      INITWRITE3          : s_cntrlNext <= WAITINITWRITE3;
      WAITINITWRITE3      : s_cntrlNext <= (s_stateReg == IDLE) ? INITBUSYWAIT1 : WAITINITWRITE3;
      default             : s_cntrlNext <= NOP;
    endcase

  always @(posedge clock) s_cntrlReg <= (reset == 1'b1) ? RES : s_cntrlNext;

  /*
   *
   * Here the statemachine is defined
   *
   */
  
  always @*
    case (s_stateReg)
      IDLE            : case (s_cntrlReg)
                          READJEDECID     : s_stateNext <= LOADJEDEC;
                          INITSTATUSWRITE,
                          INITERASE1,
                          INITWRITE1      : s_stateNext <= INITWEENA;
                          WRITESTATUSREGS : s_stateNext <= INITWESTATUS;
                          INITBUSYWAIT1,
                          INITWRITE2,
                          INITERASE2      : s_stateNext <= INITSTATUS1;
                          INITSTATR2      : s_stateNext <= INITSTATUS2;
                          INITSTATR3      : s_stateNext <= INITSTATUS3;
                          INITERASE3      : s_stateNext <= INITSECTORERASE;
                          INITWRITE3      : s_stateNext <= INITWRITE;
                          INITRESCONTREAD,
                          INITERASE0,
                          INITWRITE0      : s_stateNext <= RESCONTREAD;
                          default         : s_stateNext <= IDLE;
                        endcase
      RESCONTREAD     : s_stateNext <= WAITCONTREAD;
      WAITCONTREAD    : s_stateNext <= (s_shiftDone == 1'b1) ? IDLE : WAITCONTREAD;
      LOADJEDEC       : s_stateNext <= READJDEC;
      READJDEC        : s_stateNext <= (s_shiftDone == 1'b1) ? STOREJDEC : READJDEC;
      INITSTATUS1     : s_stateNext <= READSTATUS1;
      READSTATUS1     : s_stateNext <= (s_shiftDone == 1'b1) ? WRITESTATUS1 : READSTATUS1;
      INITSTATUS2     : s_stateNext <= READSTATUS2;
      READSTATUS2     : s_stateNext <= (s_shiftDone == 1'b1) ? WRITESTATUS2 : READSTATUS2;
      INITSTATUS3     : s_stateNext <= READSTATUS3;
      READSTATUS3     : s_stateNext <= (s_shiftDone == 1'b1) ? WRITESTATUS3 : READSTATUS3;
      INITWEENA       : s_stateNext <= WAITWEENA;
      WAITWEENA       : s_stateNext <= (s_shiftDone == 1'b1) ? WEENADONE : WAITWEENA;
      INITWESTATUS    : s_stateNext <= WAITWESTATUS;
      WAITWESTATUS    : s_stateNext <= (s_shiftDone == 1'b1) ? WESTATUSDONE : WAITWESTATUS;
      INITSECTORERASE : s_stateNext <= WAITSECTORERASE;
      WAITSECTORERASE : s_stateNext <= (s_shiftDone == 1'b1) ? IDLE : WAITSECTORERASE;
      INITWRITE       : s_stateNext <= WAITWRITECMD;
      WAITWRITECMD    : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWRITEBYTE1 : WAITWRITECMD;
      WAITWRITEBYTE1  : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWRITEBYTE2 : WAITWRITEBYTE1;
      WAITWRITEBYTE2  : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWRITEBYTE3 : WAITWRITEBYTE2;
      WAITWRITEBYTE3  : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWRITEBYTE4 : WAITWRITEBYTE3;
      WAITWRITEBYTE4  : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWRITEBYTE5 : WAITWRITEBYTE4;
      WAITWRITEBYTE5  : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWRITEBYTE6 : WAITWRITEBYTE5;
      WAITWRITEBYTE6  : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWRITEBYTE7 : WAITWRITEBYTE6;
      WAITWRITEBYTE7  : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWRITEBYTE8 : WAITWRITEBYTE7;
      WAITWRITEBYTE8  : s_stateNext <= (s_shiftDone == 1'b1) ? IDLE : WAITWRITEBYTE8;
      default         : s_stateNext <= IDLE;
    endcase

  always @(posedge clock) s_stateReg <= (reset == 1'b1) ? IDLE : s_stateNext;

  /*
   *
   * here we assign the outputs
   *
   */

  wire s_busySingle = (s_cntrlReg == NOP && s_erasePendingReg == 1'b0 && s_writePendingReg == 1'b0) ? 1'b0 : 1'b1;
  
  assign spiScl            = s_sclNext;
  assign spiNCs            = ~s_activeNext;
  assign spiSiIo0          = s_shiftNext[32];
  assign busy              = s_busySingle;
  assign resetContReadMode = (s_stateReg == RESCONTREAD) ? 1'b1 : 1'b0;
  assign flashBusy         = s_busySingle | busyIn;
endmodule
