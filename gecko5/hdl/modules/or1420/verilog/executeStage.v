module executeStage ( input wire         cpuClock,
                                         cpuReset,
                                         stall,
                      
                      // here the fetch stage if is defined
                      output reg         doJump,
                      output wire [31:2] jumpTarget,
                      input wire [31:2]  linkAddress,
                      
                      // here the spr interface is defined
                      output wire [31:0] sprDataOut,
                      output wire [15:0] sprIndex,
                      output wire        sprWe,
                      input wire [31:0]  sprDataIn,
                      input wire [31:0]  exceptionVector,
                      output wire        exceptionPrefix,
                      
                      // here the decode stage if is defined
                      input wire [31:2]  decProgramCounter,
                                         exeProgramCounter,
                      input wire [31:0]  exePortADataIn,
                                         exePortBDataIn,
                      input wire [1:0]   exeAdderCntrlIn,
                                         exeJumpMode,
                                         memStoreModeIn,
                                         exeSprControl,
                      input wire [2:0]   exeLogicCntrl,
                                         exeShiftCntrl,
                                         exeExcepMode,
                                         memLoadModeIn,
                      input wire [3:0]   exeFlagMode,
                      input wire [4:0]   wbWriteIndexIn,
                      input wire [15:0]  exeImmediate,
                      input wire         exeUpdateFlags,
                                         exeLink,
                                         exeSoftReset,
                                         exeRfe,
                                         exeCustom,
                                         exeMult,
                                         wbWriteEnableIn,
                      
                      // here the forward interface is defined
                      input wire [1:0]   exeForwardCntrlA,
                                         exeForwardCntrlB,
                      input wire [31:0]  exeWbData,
                                         memWbData,
                                         wbWbData,
                      
                      // here the memory stage if is defined
                      output reg [1:0]   memStoreMode,
                      output reg [2:0]   memLoadMode,
                      output reg [31:0]  memStoreData,
                                         wbWriteData,
                      output reg [4:0]   wbWriteIndex,
                      output reg         wbWriteEnable,

                      // here part of the custom interface is defined
                      output wire [31:0] customInstructionDataA,
                                         customInstructionDataB,
                      input wire [31:0]  customInstructionResult,
                      input wire         customInstructionDone );

  wire [31:0] s_adderResult, s_adderOperantB, s_logicResult, s_multiplierResult, s_shifterResult;
  wire [31:0] s_writeDataNext, s_customResult, s_linkAddress;
  reg [31:0] s_opperantA, s_opperantB, s_savedCiDataReg, s_memStoreDataNext;
  reg s_flagReg, s_savedFlagReg, s_carryReg, s_savedCarryReg, s_savedCiValidReg;
  wire s_adderFlag, s_adderCarryOut, s_savedFlagNext, s_flagNext, s_carryNext, s_savedCarryNext;
  wire [31:2] s_exceptionVector;

  // here the outputs are mapped
  wire s_resetControl = (cpuReset == 1'b1 || exeExcepMode != 3'b000) ? 1'b1 : 1'b0;
  always @(posedge cpuClock ) 
    if (s_resetControl == 1'b1) 
      begin
        wbWriteEnable <= 1'b0;
        memStoreMode  <= 2'b00;
        memLoadMode   <= 3'b000;
      end
    else if (stall == 1'b0)
      begin
        wbWriteEnable <= wbWriteEnableIn;
        memStoreMode  <= memStoreModeIn;
        memLoadMode   <= memLoadModeIn;
      end
  always @(posedge cpuClock ) if (stall == 1'b0) wbWriteIndex <= wbWriteIndexIn;

  // here the input opperands are defined
  always @* 
  begin
    case (exeForwardCntrlA)
      2'b00   : s_opperantA <= exePortADataIn;
      2'b01   : s_opperantA <= exeWbData;
      2'b10   : s_opperantA <= memWbData;
      default : s_opperantA <= wbWbData;
    endcase
    case (exeForwardCntrlB)
      2'b00   : s_opperantB <= exePortBDataIn;
      2'b01   : s_opperantB <= exeWbData;
      2'b10   : s_opperantB <= memWbData;
      default : s_opperantB <= wbWbData;
    endcase
  end

  // here the jump control is defined
  wire s_isException = exeExcepMode[2] | exeExcepMode[1] | exeExcepMode[0];
  always @* 
    case (exeJumpMode)
        2'b01   : doJump <= 1'b1;
        2'b10   : doJump <= s_flagReg | s_isException | exeRfe;
        2'b11   : doJump <= ~s_flagReg | s_isException | exeRfe;
        default : doJump <= exeSoftReset | s_isException | exeRfe;
    endcase

  // here the exception control is defined
  reg s_exceptionPrefixReg, s_delaySlotReg;
  reg [31:2] s_jumpPcReg, s_savedPcReg;
  wire s_exceptionPrefixNext = (cpuReset == 1'b1) ? 1'b1 : (stall == 1'b0 && exeSoftReset == 1'b1) ? 1'b0 : s_exceptionPrefixReg;
  wire s_delaySlotNext = exeJumpMode[0] | exeJumpMode[1] | exeSoftReset;
  wire [31:2] s_savedPcNext = (exeExcepMode == 3'b000) ? s_savedPcReg : 
                              (exeExcepMode == 3'b101) ? decProgramCounter :
                              (s_delaySlotReg == 1'b1) ? s_jumpPcReg : exeProgramCounter;
  assign exceptionPrefix = s_exceptionPrefixReg;
  assign jumpTarget = (exeRfe == 1'b1) ? s_savedPcReg : (exeExcepMode != 3'b000) ? exceptionVector[31:2] : s_adderResult[31:2];
  always @(posedge cpuClock ) s_exceptionPrefixReg <= s_exceptionPrefixNext;
  always @(posedge cpuClock ) if (stall == 1'b0) s_delaySlotReg <= s_delaySlotNext;
  always @(posedge cpuClock ) if (stall == 1'b0) s_jumpPcReg <= exeProgramCounter;
  always @(posedge cpuClock ) if (stall == 1'b0) s_savedPcReg <= s_savedPcNext;


  // here the memory stage signals are defined
  always @* 
    case (memStoreModeIn)
        2'b01   : s_memStoreDataNext <= {s_opperantB[7:0], s_opperantB[7:0], s_opperantB[7:0], s_opperantB[7:0]};
        2'b10   : s_memStoreDataNext <= {s_opperantB[15:0], s_opperantB[15:0]};
        default : s_memStoreDataNext <= s_opperantB;
    endcase
  always @(posedge cpuClock ) if (stall == 1'b0) memStoreData <= s_memStoreDataNext;

  // here the flag and carry are defined
  assign s_savedFlagNext  = (exeExcepMode != 3'b000) ? s_flagReg : s_savedFlagReg;
  assign s_savedCarryNext = (exeExcepMode != 3'b000) ? s_carryReg : s_savedCarryReg;
  assign s_flagNext = (exeRfe == 1'b1) ? s_savedFlagReg : s_adderFlag;
  assign s_carryNext = (exeRfe == 1'b1) ? s_savedCarryReg : (exeUpdateFlags == 1'b1) ? s_adderCarryOut : s_carryReg;

  always @(posedge cpuClock ) 
    if (stall == 1'b0) 
    begin
      s_savedFlagReg  <= s_savedFlagNext;
      s_savedCarryReg <= s_savedCarryNext;
      s_flagReg       <= s_flagNext;
      s_carryReg      <= s_carryNext;
    end

  // here the result is defined
  assign s_linkAddress = (exeLink == 1'b1) ? {linkAddress,2'b0} : {32{1'b0}};
  assign s_customResult = (s_savedCiValidReg == 1'b1) ? s_savedCiDataReg : (exeCustom == 1'b1) ? customInstructionResult : {32{1'b0}};
  assign s_writeDataNext = (exeSprControl[0] == 1'b1) ? sprDataIn :
                           (exeAdderCntrlIn == 2'b00 || exeLink == 1'b1) ? s_linkAddress | s_logicResult |
                                                                           s_shifterResult | s_multiplierResult |
                                                                           s_customResult : s_adderResult;
  always @(posedge cpuClock ) if (stall == 1'b0) wbWriteData <= s_writeDataNext;
  
  assign sprDataOut = s_opperantB;
  assign sprIndex   = s_logicResult[15:0];
  assign sprWe      = ~stall & exeSprControl[1];

  // here the components are mapped
  wire [31:0] s_logicOperantB   = (exeSprControl == 2'd0) ? s_opperantB : {16'd0,exeImmediate};
  assign s_adderOperantB[31:16] = (memStoreModeIn == 2'b00 &&
                                   memLoadModeIn == 3'b000) ? s_opperantB[31:16] : {16{exeImmediate[15]}};
  assign s_adderOperantB[15:0]  = (memStoreModeIn == 2'b00 &&
                                   memLoadModeIn == 3'b000) ? s_opperantB[15:0] : exeImmediate;
  adder addSub ( .flagIn(s_flagReg),
                 .carryIn(s_carryReg),
                 .opcode(exeAdderCntrlIn),
                 .flagMode(exeFlagMode),
                 .operantA(s_opperantA),
                 .operantB(s_adderOperantB),
                 .flagOut(s_adderFlag),
                 .carryOut(s_adderCarryOut),
                 .result(s_adderResult) );

  logicUnit logicU (.opcode(exeLogicCntrl),
                    .operantA(s_opperantA),
                    .operantB(s_logicOperantB),
                    .result(s_logicResult) );

  multiplier mul ( .doMultiply(exeMult),
                   .operantA(s_opperantA),
                   .operantB(s_opperantB),
                   .result(s_multiplierResult) );

  shifter shift ( .control(exeShiftCntrl),
                  .flagIn(s_flagReg),
                  .operantA(s_opperantA),
                  .operantB(s_adderOperantB),
                  .result(s_shifterResult) );
  
  // here the custom interface signals are defined
  wire s_weSavedCiReg = stall & customInstructionDone;
  wire s_saveCiValidNext = (stall == 1'b0 || cpuReset == 1'b1) ? 1'b0 : (s_weSavedCiReg == 1'b1) ? 1'b1 : s_savedCiValidReg;
  assign customInstructionDataA = s_opperantA;
  assign customInstructionDataB = s_opperantB;

  always @(posedge cpuClock ) if (s_weSavedCiReg) s_savedCiDataReg <= customInstructionResult;
  always @(posedge cpuClock ) s_savedCiValidReg <= s_saveCiValidNext;
endmodule
