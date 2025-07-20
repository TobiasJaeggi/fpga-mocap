module spiShiftQuad ( input wire         clock,
                                         reset,
                                         resetContReadMode,
                                         start,
                      input wire [23:0]  flashAddress,
                      input wire [7:0]   nrOfWords,
                      output wire        contReadModeEnabled,
                                         dataOutValid,
                      output wire [31:0] dataOut,
                      
                      input wire         busyIn,
                                         busErrorIn,
                      output wire        busyOut,
                      
                      // here the flash-chip interface is defined
                      output wire        spiScl,
                                         spiNCs,
                      input wire [3:0]   spiSiIoIn,
                      output wire [3:0]  spiSiIoOut,
                                         spiSiIoTristateEnable );

  localparam [3:0] IDLE = 4'd0, WAITBUSY = 4'd1, CHECKBUSY = 4'd2, SENDCOMMAND = 4'd3, WAITCOMMAND = 4'd4,
                   INITADDRESS = 4'd5, WAITADDRESS = 4'd6, WAITDUMMY = 4'd7, WAITWORD = 4'd8;
  
  reg [3:0] s_stateReg, s_stateNext;
  
  /*
   *
   * Here the four shift registers are defined (one for each I/O pin)
   *
   */
  reg [8:0] s_shift0Reg, s_shift1Reg, s_shift2Reg, s_shift3Reg;
  reg s_activeReg, s_sclReg;
  wire s_loadAddress;
  wire [8:0] s_shift0Next = (s_stateReg == SENDCOMMAND) ? 9'hEB :
                            (s_stateReg == INITADDRESS) ? {1'b0,flashAddress[20],flashAddress[16],flashAddress[12],flashAddress[8],flashAddress[4],3'd0} :
                            (s_loadAddress == 1'b1) ? {flashAddress[20],flashAddress[16],flashAddress[12],flashAddress[8],flashAddress[4],4'd0} :
                            (s_activeReg == 1'b1 && s_sclReg == 1'b1) ? {s_shift0Reg[7:0], spiSiIoIn[0]} : s_shift0Reg;
  wire [8:0] s_shift1Next = (s_stateReg == INITADDRESS) ? {1'b0,flashAddress[21],flashAddress[17],flashAddress[13],flashAddress[9],flashAddress[5],
                                                           `ifdef GECKO5Education 3'd0 `else 3'd2 `endif} :
                            (s_loadAddress == 1'b1) ? {flashAddress[21],flashAddress[17],flashAddress[13],flashAddress[9],flashAddress[5],
                                                       `ifdef GECKO5Education 4'd0 `else 4'd4 `endif} :
                            (s_activeReg == 1'b1 && s_sclReg == 1'b1) ? {s_shift1Reg[7:0], spiSiIoIn[1]} : s_shift1Reg;
  wire [8:0] s_shift2Next = (s_stateReg == INITADDRESS) ? {1'b0,flashAddress[22],flashAddress[18],flashAddress[14],flashAddress[10],flashAddress[6],flashAddress[2],2'd0} :
                            (s_loadAddress == 1'b1) ? {flashAddress[22],flashAddress[18],flashAddress[14],flashAddress[10],flashAddress[6],flashAddress[2],3'd0} :
                            (s_activeReg == 1'b1 && s_sclReg == 1'b1) ? {s_shift2Reg[7:0], spiSiIoIn[2]} : s_shift2Reg;
  wire [8:0] s_shift3Next = (s_stateReg == INITADDRESS) ? {1'b0,flashAddress[23],flashAddress[19],flashAddress[15],flashAddress[11],flashAddress[7],flashAddress[3],2'd0} :
                            (s_loadAddress == 1'b1) ? {flashAddress[23],flashAddress[19],flashAddress[15],flashAddress[11],flashAddress[7],flashAddress[3],3'd0} :
                            (s_activeReg == 1'b1 && s_sclReg == 1'b1) ? {s_shift3Reg[7:0], spiSiIoIn[3]} : s_shift3Reg;
  
  always @(posedge clock)
    begin
      s_shift0Reg <= (reset == 1'b1) ? 9'd0 : s_shift0Next;
      s_shift1Reg <= (reset == 1'b1) ? 9'd0 : s_shift1Next;
      s_shift2Reg <= (reset == 1'b1) ? 9'd0 : s_shift2Next;
      s_shift3Reg <= (reset == 1'b1) ? 9'd0 : s_shift3Next;
    end
  
  /*
   *
   * Here the word counter is defined
   *
   */
  reg [8:0] s_wordCountReg;
  wire s_nextWord;
  wire [8:0] s_wordCountNext = (start == 1'b1) ? {1'b0, nrOfWords} :
                               (s_nextWord == 1'b1) ? s_wordCountReg - 9'd1 : s_wordCountReg;
  
  always @(posedge clock) s_wordCountReg <= (reset == 1'b1 || busErrorIn == 1'b1) ? 9'b100000000 : s_wordCountNext;
  
  /*
   *
   * Here all control signals are defined
   *
   */
  reg s_contReadModeEnabledReg;
  wire s_shiftDone;
  wire s_initDummy = (s_stateReg == WAITADDRESS) ? s_shiftDone : 1'b0;
  wire s_wordValid = (s_stateReg == WAITWORD) ? s_shiftDone : 1'b0;
  wire s_contReadModeEnabledNext = `ifdef GECKO5Education 
                                     1'b0;
                                   `else
                                     (reset == 1'b1 || resetContReadMode == 1'b1) ? 1'b0 :
                                     (s_stateReg == SENDCOMMAND) ? 1'b1 : s_contReadModeEnabledReg;
                                   `endif
  
  assign s_loadAddress = (s_stateReg == WAITCOMMAND) ? s_shiftDone : 1'b0;
  assign s_nextWord = (s_stateReg == WAITDUMMY || (s_stateReg == WAITWORD && s_wordCountReg[8] == 1'b0)) ? s_shiftDone : 1'b0;
  
  always @(posedge clock) s_contReadModeEnabledReg <= s_contReadModeEnabledNext;
  
  /*
   *
   * Here the clock is defined
   *
   */
  wire s_activeNext = (s_stateReg == SENDCOMMAND || s_stateReg == INITADDRESS) ? 1'b1 :
                      (s_shiftDone == 1'b1 && s_loadAddress == 1'b0 && s_initDummy == 1'b0 && s_nextWord == 1'b0) ? 1'b0 : s_activeReg;
  wire s_sclNext = (s_activeNext == 1'b0 || s_activeReg == 1'b0 || reset == 1'b1) ? 1'b1 : ~s_sclReg;

  always @(posedge clock)
    begin
      s_sclReg    <= s_sclNext;
      s_activeReg <= (reset == 1'b1) ? 1'b0 : s_activeNext;
    end

 /*
  *
  * Here the bit-counting is defined
  *
  */
  reg [3:0] s_bitCountReg;
  wire [3:0] s_bitCountNext = (s_stateReg == SENDCOMMAND || s_stateReg == INITADDRESS) ? 4'd7 :
                              (s_loadAddress == 1'b1 || s_nextWord == 1'd1) ? 4'd6 :
                              (s_initDummy == 1'b1) ? 4'd2:
                              (s_activeReg == 1'b1 && s_sclReg == 1'b1 && s_bitCountReg[3] == 1'b0) ? s_bitCountReg - 4'd1 : s_bitCountReg;
  
  assign s_shiftDone = s_bitCountReg[3] & s_sclReg;
  
  always @(posedge clock) s_bitCountReg <= (reset == 1'b1) ? 4'd0 : s_bitCountNext;

  /*
   *
   * Here the state machine is defined
   *
   */

  always @*
    case (s_stateReg)
      IDLE            : s_stateNext <= (start == 1'b1) ? WAITBUSY : IDLE;
      WAITBUSY        : s_stateNext <= (busyIn == 1'b1) ? WAITBUSY : CHECKBUSY;
      CHECKBUSY       : s_stateNext <= (busyIn == 1'b1) ? WAITBUSY :
                                       `ifdef GECKO5Education SENDCOMMAND; `else (s_contReadModeEnabledReg == 1'b0) ? SENDCOMMAND : INITADDRESS; `endif
      SENDCOMMAND     : s_stateNext <= WAITCOMMAND;
      WAITCOMMAND     : s_stateNext <= (s_shiftDone == 1'b1) ? WAITADDRESS : WAITCOMMAND;
      INITADDRESS     : s_stateNext <= WAITADDRESS;
      WAITADDRESS     : s_stateNext <= (s_shiftDone == 1'b1) ? WAITDUMMY : WAITADDRESS;
      WAITDUMMY       : s_stateNext <= (s_shiftDone == 1'b1) ? WAITWORD : WAITDUMMY;
      WAITWORD        : s_stateNext <= (s_shiftDone == 1'b1 && s_nextWord == 1'b0) ? IDLE : WAITWORD;
      default         : s_stateNext <= IDLE;
    endcase
  
  always @(posedge clock) s_stateReg <= (reset == 1'b1) ? IDLE : s_stateNext;

  /*
   *
   * Here the outputs are defined
   *
   */
  reg s_dataOutValidReg, s_wordValidReg;
  reg [31:0] s_dataOutReg;

  assign dataOutValid = s_dataOutValidReg;
  assign dataOut = s_dataOutReg;
  assign contReadModeEnabled = s_contReadModeEnabledReg;
  assign spiNCs = ~s_activeNext;
  assign spiScl = s_sclNext;
  assign spiSiIoOut[0] = s_shift0Next[8];
  assign spiSiIoOut[1] = s_shift1Next[8];
  assign spiSiIoOut[2] = s_shift2Next[8];
  assign spiSiIoOut[3] = s_shift3Next[8];
  assign spiSiIoTristateEnable[0] = (s_stateNext == WAITDUMMY || s_stateNext == WAITWORD) ? 1'b1 : 1'b0;
  assign spiSiIoTristateEnable[3:1] = (s_stateNext == INITADDRESS || s_stateNext == WAITADDRESS) ? 3'd0 : 3'b111;
  assign busyOut = (s_stateReg == IDLE || s_stateReg == WAITBUSY) ? 1'b0 : 1'b1;

  always @(posedge clock)
    begin
      s_wordValidReg    <= s_wordValid & ~reset;
      s_dataOutValidReg <= s_wordValidReg & ~reset;
      s_dataOutReg      <= (reset == 1'b0 && s_wordValidReg == 1'b1) ? {s_shift3Reg[1], s_shift2Reg[1], s_shift1Reg[1], s_shift0Reg[1],
                                                                        s_shift3Reg[0], s_shift2Reg[0], s_shift1Reg[0], s_shift0Reg[0],
                                                                        s_shift3Reg[3], s_shift2Reg[3], s_shift1Reg[3], s_shift0Reg[3],
                                                                        s_shift3Reg[2], s_shift2Reg[2], s_shift1Reg[2], s_shift0Reg[2],
                                                                        s_shift3Reg[5], s_shift2Reg[5], s_shift1Reg[5], s_shift0Reg[5],
                                                                        s_shift3Reg[4], s_shift2Reg[4], s_shift1Reg[4], s_shift0Reg[4],
                                                                        s_shift3Reg[7], s_shift2Reg[7], s_shift1Reg[7], s_shift0Reg[7],
                                                                        s_shift3Reg[6], s_shift2Reg[6], s_shift1Reg[6], s_shift0Reg[6]} : 32'd0;
    end  
endmodule
