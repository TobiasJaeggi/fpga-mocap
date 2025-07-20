module decodeStage ( input wire  cpuClock,
                                 cpuReset,
                                 stall,
                                 irq,
                                 dCacheError,
                     output wire dataDependencyStall,
                                 customInstructionStall,
                     
                     // here the fetch-stage interface is defined
                     input wire [31:0] instruction,
                     input wire        validInstruction,
                     input wire [31:2] programCounter,
                     output wire       insertNop,
                     
                     // here the register-file interface is defined
                     output wire [4:0] readAddressA,
                                       readAddressB,
                     input wire [31:0] registerDataA,
                                       registerDataB,
                     output wire       inExceptionMode,
                     
                     // here the forward detection interface is defined
                     input wire [4:0] exeStageWbIndex,
                                      memStageWbIndex,
                                      wbStageWbIndex,
                     input wire       exeStageWbWe,
                                      memStageWbWe,
                                      wbStageWbWe,
                     
                     // here the exe-stage interface is defined
                     output reg [31:2] exeProgramCounter,
                     output reg [31:0] exePortAData,
                                       exePortBData,
                     output reg [1:0]  exeForwardCntrlA,
                                       exeForwardCntrlB,
                                       exeAdderCntrl,
                     output reg [2:0]  exeLogicCntrl,
                                       exeShiftCntrl,
                     output reg        exeUpdateFlags,
                     output reg [1:0]  exeJumpMode,
                                       exeSprControl,
                     output reg        exeLink,
                     output reg [3:0]  exeFlagMode,
                     output reg        exeSoftReset,
                     output wire [2:0] exeExceptionMode,
                     output reg        exeRfe,
                     output reg [15:0] exeImmediate,
                     output wire       exeCustom,
                     output reg        exeMult,
                     output reg [1:0]  memStoreMode,
                     output wire [2:0] memLoadMode,
                     input wire [2:0]  memstageLoadMode,
                     input wire        wbStageLoadPending,
                     output reg [4:0]  wbWriteIndex,
                     output reg        wbWriteEnable,
                     
                     // here part of the custom instruction interface is defined
                     output wire      customInstructionStart,
                     output reg [7:0] customInatructionN,
                     output reg [4:0] customInstructionA,
                                      customInstructionB,
                                      customInstructionD,
                     output reg       customInstructionReadRa,
                                      customInstructionReadRb,
                                      customInstructionWriteRd,
                     input wire       customInstructionDone );

  reg s_flushReg;
  reg [2:0] s_exeLoadModeReg, s_exceptionModeReg;
  reg [3:0]  s_irqRequestReg;
  reg s_inExcepModeReg, s_dCacheErrorReg;
  wire s_isException;
  // assign the register file signals
  assign readAddressA = instruction[20:16];
  assign readAddressB = instruction[15:11];
  assign memLoadMode = s_exeLoadModeReg;
  assign exeExceptionMode = s_exceptionModeReg;
  assign inExceptionMode = s_inExcepModeReg;
  always @(posedge cpuClock) if (stall == 1'b0) exeProgramCounter <= programCounter;
  
  // here we do the decoding
  wire s_systemCall = instruction[31:16] == 16'h2000 ? 1'b1 : 1'b0;
  wire s_isJump = (instruction[31:26] == 6'b000000) // J
                  ||
                  (instruction[31:26] == 6'b000001) // JAL
                  ||
                  (instruction[31:26] == 6'b010001) // JR
                  ||
                  (instruction[31:26] == 6'b010010) // JALR
                  ||
                  (instruction[31:26] == 6'b000100) // BF
                  ||
                  (instruction[31:26] == 6'b000011) // BNF
                  ? ~s_flushReg : 1'b0;
  wire s_executeNext = ( (instruction[31:24] == 8'b00010101) // NOP instruction
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         (instruction[3:0] == 4'h2 || // SUB
                          instruction[3:0] == 4'h0 || // ADD
                          instruction[3:0] == 4'h1))  // ADDC
                        ||
                        (instruction[31:26] == 6'b101101) //MFSPR
                        ||
                        (instruction[31:26] == 6'b110000) //MTSPR
                        ||
                        (instruction[31:26] == 6'b100111) // ADDI
                        ||
                        (instruction[31:26] == 6'b101000) // ADDIC
                        ||
                        (instruction[31:26] == 6'b110110) // SB
                        ||
                        (instruction[31:26] == 6'b110111) // SHW
                        ||
                        (instruction[31:26] == 6'b110101) // SW
                        ||
                        (instruction[31:26] == 6'b100100) // LBS
                        ||
                        (instruction[31:26] == 6'b100011) // LBZ
                        ||
                        (instruction[31:26] == 6'b100110) // LHS
                        ||
                        (instruction[31:26] == 6'b100101) // LHZ
                        ||
                        (instruction[31:26] == 6'b100010) // LWS
                        ||
                        (instruction[31:26] == 6'b100001) // LWZ
                        ||
                        (instruction[31:26] == 6'b000000) // J
                        ||
                        (instruction[31:26] == 6'b000001) // JAL
                        ||
                        (instruction[31:26] == 6'b010001) // JR
                        ||
                        (instruction[31:26] == 6'b010010) // JALR
                        ||
                        (instruction[31:26] == 6'b000100) // BF
                        ||
                        (instruction[31:26] == 6'b000011) // BNF
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[9:6] == 4'h0 &&
                         instruction[3:0] == 4'hD) // EXTWZ
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[9:6] == 4'h1 &&
                         instruction[3:0] == 4'hD) // EXTWS
                        ||
                        (instruction[31:25] == 7'b1110010) // SFxx
                        ||
                        (instruction[31:25] == 7'b1011110) // SFIxx
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         instruction[3:0] == 4'h3) // AND
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         instruction[3:0] == 4'h4) // OR
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         instruction[3:0] == 4'h5) // XOR
                        ||
                        (instruction[31:26] == 6'b101001) // ANDI
                        ||
                        (instruction[31:26] == 6'b101010) // ORI
                        ||
                        (instruction[31:26] == 6'b101011) // XORI
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         instruction[3:0] == 4'h8) // shift
                        ||
                        (instruction[31:26] == 6'b101110 &&
                         instruction[10] == 1'b0) // shift I
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[9:8] == 2'b00 &&
                         instruction[3:0] == 4'hE) // CMOV
                        ||
                        (instruction[31:26] == 6'b000110 &&
                         instruction[20:16] == 5'b00000) // MIH
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[9:8] == 2'b00 &&
                         instruction[3:0] == 4'hC) // extend
                        ||
                        (instruction[31:26] == 6'b011101) // jump program 0x30
                        ||
                        (instruction[31:26] == 6'b001001) // RFE
                        ||
                        (instruction[31:26] == 6'b011100) // Custom Instruction
                        ||
                        (s_systemCall == 1)
                        ||
                        (instruction[31:26] == 6'b101100) // MULI
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b011 &&
                         (instruction[3:0] == 4'b0110 ||
                          instruction[3:0] == 4'b1011)) // MUL 
                     ) ? 1'b1 : 1'b0;
  wire [4:0] s_wbIndexNext = (instruction[31:25] == 7'b1110010) // SFxx
                             ||
                             (instruction[31:25] == 7'b1011110) // SFIxx
                             ||
                             (instruction[31:26] == 6'b011101) // jump program 0x30
                             ||
                             (instruction[31:26] == 6'b000000) // J
                             ||
                             (instruction[31:26] == 6'b010001) // JR
                             ||
                             (instruction[31:26] == 6'b000100) // BF
                             ||
                             (instruction[31:26] == 6'b000011) // BNF
                             ||
                             (instruction[31:26] == 6'b110110) // SB
                             ||
                             (instruction[31:26] == 6'b110111) // SHW
                             ||
                             (instruction[31:26] == 6'b110101) // SW
                             ||
                             (instruction[31:26] == 6'b011100 &&
                              instruction[8] == 1'b1) // Custom Instruction
                             ? 5'd0 : // to avoid false data dependency stalls
                             (instruction[31:26] == 6'b000001) // JAL
                             ||
                             (instruction[31:26] == 6'b010010) // JALR
                             ? 5'd9 : instruction[25:21];
  always @(posedge cpuClock) if (stall == 1'b0) wbWriteIndex <= s_wbIndexNext;
  wire [4:0] s_regAIdxNext = (s_flushReg == 1'b1)
                             ||
                             (instruction[31:24] == 8'b00010101) // NOP instruction
                             ||
                             (instruction[31:26] == 6'b000000) // J
                             ||
                             (instruction[31:26] == 6'b000001) // JAL
                             ||
                             (instruction[31:26] == 6'b010001) // JR
                             ||
                             (instruction[31:26] == 6'b010010) // JALR
                             ||
                             (instruction[31:26] == 6'b000100) // BF
                             ||
                             (instruction[31:26] == 6'b000011) // BNF
                             ||
                             (instruction[31:26] == 6'b111000 &&
                              instruction[9:6] == 4'h0 &&
                              instruction[3:0] == 4'hD) // EXTWZ
                             ||
                             (instruction[31:26] == 6'b111000 &&
                              instruction[9:6] == 4'h1 &&
                              instruction[3:0] == 4'hD) // EXTWS
                             ||
                             (instruction[31:26] == 6'b000110 &&
                              instruction[20:16] == 5'b00000) // MIH
                             ||
                             (instruction[31:26] == 6'b011101) // jump program 0x30
                             ||
                             (instruction[31:26] == 6'b001001) // RFE
                             ||
                             (instruction[31:26] == 6'b011100 &&
                              instruction[10] == 1'b1) // Custom Instruction
                             ? 5'b00000 : instruction[20:16];
  wire [4:0] s_regBIdxNext = (s_flushReg == 1'b1)
                             ||
                             (s_systemCall == 1'b1)
                             ||
                             (instruction[31:24] == 8'b00010101) // NOP instruction
                             ||
                             (instruction[31:26] == 6'b100111) // ADDI
                             ||
                             (instruction[31:26] == 6'b101000) // ADDIC
                             ||
                             (instruction[31:26] == 6'b000000) // J
                             ||
                             (instruction[31:26] == 6'b000001) // JAL
                             ||
                             (instruction[31:26] == 6'b000100) // BF
                             ||
                             (instruction[31:26] == 6'b000011) // BNF
                             ||
                             (instruction[31:25] == 7'b1011110) // SFIxx
                             ||
                             (instruction[31:26] == 6'b111000 &&
                              instruction[9:6] == 4'h0 &&
                              instruction[3:0] == 4'hD) // EXTWZ
                             ||
                             (instruction[31:26] == 6'b111000 &&
                              instruction[9:6] == 4'h1 &&
                              instruction[3:0] == 4'hD) // EXTWS
                             ||
                             (instruction[31:26] == 6'b101001) // ANDI
                             ||
                             (instruction[31:26] == 6'b101010) // ORI
                             ||
                             (instruction[31:26] == 6'b101011) // XORI
                             ||
                             (instruction[31:26] == 6'b101110 &&
                              instruction[10] == 1'b0) // shift I
                             ||
                             (instruction[31:26] == 6'b000110 &&
                              instruction[20:16] == 5'b00000) // MIH
                             ||
                             (instruction[31:26] == 6'b111000 &&
                              instruction[9:8] == 2'b00 &&
                              instruction[3:0] == 4'hC) // extend
                             ||
                             (instruction[31:26] == 6'b011101) // jump program 0x30
                             ||
                             (instruction[31:26] == 6'b001001) // RFE
                             ||
                             (instruction[31:26] == 6'b011100 &&
                              instruction[10] == 1'b1) // Custom Instruction
                             ||
                             (instruction[31:26] == 6'b101100) // MULI
                             ? 5'b00000 : instruction[15:11];
  wire s_dataDependencyStall = (s_isJump == 1'b1
                                ||
                                (instruction[31:26] == 6'b011100 &&
                                 instruction[10:9] != 2'b00) // Custom Instruction
                                ||
                                (s_regAIdxNext != 5'b00000 &&
                                 (s_regAIdxNext == exeStageWbIndex ||
                                  s_regAIdxNext == memStageWbIndex ||
                                  s_regAIdxNext == wbStageWbIndex))
                                ||
                                (s_regBIdxNext != 5'b00000 &&
                                 (s_regBIdxNext == exeStageWbIndex ||
                                  s_regBIdxNext == memStageWbIndex ||
                                  s_regBIdxNext == wbStageWbIndex))
                                ||
                                (instruction[15:11] != 5'b0000 &&
                                 (instruction[15:11] == exeStageWbIndex ||
                                  instruction[15:11] == memStageWbIndex ||
                                  instruction[15:11] == wbStageWbIndex) &&
                                 (instruction[31:26] == 6'b110110 || // SB
                                  instruction[31:26] == 6'b110111 || // SHW
                                  instruction[31:26] == 6'b110101)))  // SW
                               &&
                               (s_exeLoadModeReg != 3'b000 ||
                                memstageLoadMode != 3'b000 ||
                                wbStageLoadPending == 1'b1)
                               &&
                               s_exceptionModeReg == 3'b000 ? 1'b1 : 1'b0;
  assign dataDependencyStall = s_dataDependencyStall;
  wire s_wbEnableNext = (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         (instruction[3:0] == 4'h2 || // SUB
                          instruction[3:0] == 4'h0 || // ADD
                          instruction[3:0] == 4'h1))  // ADDC
                        ||
                        (instruction[31:26] == 6'b101101) //MFSPR
                        ||
                        (instruction[31:26] == 6'b100111) // ADDI
                        ||
                        (instruction[31:26] == 6'b000001) // JAL
                        ||
                        (instruction[31:26] == 6'b010010) // JALR
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         instruction[3:0] == 4'h3) // AND
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         instruction[3:0] == 4'h4) // OR
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         instruction[3:0] == 4'h5) // XOR
                        ||
                        (instruction[31:26] == 6'b101001) // ANDI
                        ||
                        (instruction[31:26] == 6'b101010) // ORI
                        ||
                        (instruction[31:26] == 6'b101011) // XORI
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b000 &&
                         instruction[3:0] == 4'h8) // shift
                        ||
                        (instruction[31:26] == 6'b101110 &&
                         instruction[10] == 1'b0) // shift I
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[9:8] == 2'b00 &&
                         instruction[3:0] == 4'hE) // CMOV
                        ||
                        (instruction[31:26] == 6'b000110 &&
                         instruction[20:16] == 5'b00000) // MIH
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[9:8] == 2'b00 &&
                         instruction[3:0] == 4'hC) // extend
                        ||
                        (instruction[31:26] == 6'b011100 &&
                         instruction[8] == 1'b0) // Custom Instruction
                        ||
                        (instruction[31:26] == 6'b101100) // MULI
                        ||
                        (instruction[31:26] == 6'b111000 &&
                         instruction[10:8] == 3'b011 &&
                         (instruction[3:0] == 4'b0110 ||
                          instruction[3:0] == 4'b1011)) // MUL 
                        ? validInstruction & ~s_dataDependencyStall & ~s_flushReg : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) wbWriteEnable <= 1'b0;
                             else if (stall == 1'b0) wbWriteEnable <= s_wbEnableNext;
  wire [31:0] s_regANext = (instruction[31:26] == 6'b010001) // JR
                           ||
                           (instruction[31:26] == 6'b010010) // JALR
                           ||
                           (instruction[31:26] == 6'b011101) // jump program 0x30
                           ? {32{1'b0}} :
                           (instruction[31:26] == 6'b000000) // J
                           ||
                           (instruction[31:26] == 6'b000001) // JAL
                           ||
                           (instruction[31:26] == 6'b000100) // BF
                           ||
                           (instruction[31:26] == 6'b000011) // BNF
                           ? {programCounter,2'b00} : registerDataA;
  always @(posedge cpuClock) if (stall == 1'b0) exePortAData <= s_regANext;
  wire [31:0] s_immediateValue;
  assign s_immediateValue[31:16] = (instruction[31:26] == 6'b011101) // jump program 0x30
                                   ||
                                   (instruction[31:26] == 6'b101001) // ANDI
                                   ||
                                   (instruction[31:26] == 6'b101010) // ORI
                                   ? {16{1'b0}} :
                                   (instruction[31:26] == 6'b000000) // J
                                   ||
                                   (instruction[31:26] == 6'b000001) // JAL
                                   ||
                                   (instruction[31:26] == 6'b000100) // BF
                                   ||
                                   (instruction[31:26] == 6'b000011) // BNF
                                   ? {instruction[25],instruction[25],instruction[25],instruction[25],instruction[25:14]} : {16{instruction[15]}};
  assign s_immediateValue[15:0] = (instruction[31:26] == 6'b000000) // J
                                  ||
                                  (instruction[31:26] == 6'b000001) // JAL
                                  ||
                                  (instruction[31:26] == 6'b000100) // BF
                                  ||
                                  (instruction[31:26] == 6'b000011) // BNF
                                  ? {instruction[13:0],2'b0} : instruction[15:0];
  wire [31:0] s_regBNext = (instruction[31:26] == 6'b100111) // ADDI
                           ||
                           (instruction[31:26] == 6'b101000) // ADDIC
                           ||
                           (instruction[31:26] == 6'b000000) // J
                           ||
                           (instruction[31:26] == 6'b000001) // JAL
                           ||
                           (instruction[31:25] == 7'b1011110) // SFIxx
                           ||
                           (instruction[31:26] == 6'b000100) // BF
                           ||
                           (instruction[31:26] == 6'b000011) // BNF
                           ||
                           (instruction[31:26] == 6'b101001) // ANDI
                           ||
                           (instruction[31:26] == 6'b101010) // ORI
                           ||
                           (instruction[31:26] == 6'b101011) // XORI
                           ||
                           (instruction[31:26] == 6'b101110 &&
                            instruction[10] == 1'b0) // shift I
                           ||
                           (instruction[31:26] == 6'b000110 &&
                            instruction[20:16] == 5'b00000) // MIH
                           ||
                           (instruction[31:26] == 6'b011101) // jump program 0x30
                           ||
                           (instruction[31:26] == 6'b101100) // MULI
                           ? s_immediateValue : registerDataB;
  always @(posedge cpuClock) if (stall == 1'b0) exePortBData <= s_regBNext;

  wire[1:0] s_exeAdderCntrlNext;
  assign s_exeAdderCntrlNext[0] = (instruction[31:26] == 6'b111000 &&
                                   instruction[10:8] == 3'b000 &&
                                   (instruction[3:0] == 4'h2 || // SUB
                                    instruction[3:0] == 4'h0)) // ADD
                                  ||
                                  (instruction[31:26] == 6'b100111) // ADDI
                                  ||
                                  (instruction[31:26] == 6'b110110) // SB
                                  ||
                                  (instruction[31:26] == 6'b110111) // SHW
                                  ||
                                  (instruction[31:26] == 6'b110101) // SW
                                  ||
                                  (instruction[31:26] == 6'b100100) // LBS
                                  ||
                                  (instruction[31:26] == 6'b100011) // LBZ
                                  ||
                                  (instruction[31:26] == 6'b100110) // LHS
                                  ||
                                  (instruction[31:26] == 6'b100101) // LHZ
                                  ||
                                  (instruction[31:26] == 6'b100010) // LWS
                                  ||
                                  (instruction[31:26] == 6'b100001) // LWZ
                                  ||
                                  (instruction[31:26] == 6'b000000) // J
                                  ||
                                  (instruction[31:26] == 6'b000001) // JAL
                                  ||
                                  (instruction[31:26] == 6'b010001) // JR
                                  ||
                                  (instruction[31:26] == 6'b010010) // JALR
                                  ||
                                  (instruction[31:26] == 6'b000100) // BF
                                  ||
                                  (instruction[31:26] == 6'b000011) // BNF
                                  ||
                                  (instruction[31:25] == 7'b1110010) // SFxx
                                  ||
                                  (instruction[31:25] == 7'b1011110) // SFIxx
                                  ||
                                  (instruction[31:26] == 6'b011101) // jump program 0x30
                                  ? 1'b1 : 1'b0;
  assign s_exeAdderCntrlNext[1] = (instruction[31:26] == 6'b111000 &&
                                   instruction[10:8] == 3'b000 &&
                                   (instruction[3:0] == 4'h2 || // SUB
                                    instruction[3:0] == 4'h1))  // ADDC
                                  ||
                                  (instruction[31:26] == 6'b101000) // ADDIC
                                  ||
                                  (instruction[31:25] == 7'b1110010) // SFxx
                                  ||
                                  (instruction[31:25] == 7'b1011110) // SFIxx
                                  ? 1'b1 : 1'b0;
  always @(posedge cpuClock) if (stall == 1'b0) exeAdderCntrl <= s_exeAdderCntrlNext;

  wire s_exeUpdateFlagsNext = (instruction[31:26] == 6'b111000 &&
                               instruction[10:8] == 3'b000 &&
                               (instruction[3:0] == 4'h2 || // SUB
                                instruction[3:0] == 4'h0 || // ADD
                                instruction[3:0] == 4'h1))  // ADDC
                              ||
                              (instruction[31:26] == 6'b100111) // ADDI
                              ||
                              (instruction[31:26] == 6'b101000) // ADDIC
                              ? ~s_dataDependencyStall & ~s_flushReg : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeUpdateFlags <= 1'b0;
                             else if (stall == 1'b0) exeUpdateFlags <= s_exeUpdateFlagsNext;

  wire s_canExecute = ~s_dataDependencyStall && ~s_flushReg;
  wire [1:0] s_storeModeNext;
  assign s_storeModeNext[0] = (instruction[31:26] == 6'b110110) // SB
                              ||
                              (instruction[31:26] == 6'b110101) // SW
                              ? ~s_dataDependencyStall && ~s_flushReg : 1'b0;
  assign s_storeModeNext[1] = (instruction[31:26] == 6'b110111) // SHW
                              ||
                              (instruction[31:26] == 6'b110101) // SW
                              ? s_canExecute : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) memStoreMode = 2'b00;
                             else if (stall == 1'b0) memStoreMode = s_storeModeNext;
  

  wire[2:0] s_loadModeNext;
  assign s_loadModeNext[0] = (instruction[31:26] == 6'b100100) // LBS
                             ||
                             (instruction[31:26] == 6'b100011) // LBZ
                             ||
                             (instruction[31:26] == 6'b100010) // LWS
                             ||
                             (instruction[31:26] == 6'b100001) // LWZ
                             ? s_canExecute : 1'b0;
  assign s_loadModeNext[1] = (instruction[31:26] == 6'b100110) // LHS
                             ||
                             (instruction[31:26] == 6'b100101) // LHZ
                             ||
                             (instruction[31:26] == 6'b100010) // LWS
                             ||
                             (instruction[31:26] == 6'b100001) // LWZ
                             ? s_canExecute : 1'b0;
  assign s_loadModeNext[2] = (instruction[31:26] == 6'b100100) // LBS
                             ||
                             (instruction[31:26] == 6'b100110) // LHS
                             ||
                             (instruction[31:26] == 6'b100010) // LWS
                             ? s_canExecute : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) s_exeLoadModeReg = 3'b000;
                             else if (stall == 1'b0) s_exeLoadModeReg = s_loadModeNext;

  wire[1:0] s_jumpModeNext;
  assign s_jumpModeNext[0] = (instruction[31:26] == 6'b000000) // J
                             ||
                             (instruction[31:26] == 6'b000001) // JAL
                             ||
                             (instruction[31:26] == 6'b010001) // JR
                             ||
                             (instruction[31:26] == 6'b010010) // JALR
                             ||
                             (instruction[31:26] == 6'b000011) // BNF
                             ? s_canExecute : 1'b0;
  assign s_jumpModeNext[1] = (instruction[31:26] == 6'b000100) // BF
                             ||
                             (instruction[31:26] == 6'b000011) // BNF
                             ? s_canExecute : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeJumpMode <= 2'b00;
                             else if (stall == 1'b0) exeJumpMode <= s_jumpModeNext;

  wire s_linkNext = (instruction[31:26] == 6'b000001) // JAL
                    ||
                    (instruction[31:26] == 6'b010010) // JALR
                    ? s_canExecute : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeLink <= 1'b0;
                             else if (stall == 1'b0) exeLink <= s_linkNext;

  wire [3:0] s_exeFlagModeNext  = ((instruction[31:25] == 7'b1110010 || // SFxx
                                    instruction[31:25] == 7'b1011110) // SFIxx
                                  && s_flushReg == 1'b0 )
                                  ? instruction[24:21] : 4'hF;
  always @(posedge cpuClock) if (stall == 1'b0) exeFlagMode <= s_exeFlagModeNext;
  
  wire [15:0] s_exeImmediateNext = (instruction[31:26] == 6'b110110) // SB
                                   ||
                                   (instruction[31:26] == 6'b110111) // SHW
                                   ||
                                   (instruction[31:26] == 6'b110101) // SW
                                   ||
                                   (instruction[31:26] == 6'b110000) // MTSPR
                                   ? {instruction[25:21],instruction[10:0]} : instruction[15:0];
  always @(posedge cpuClock) if (stall == 1'b0) exeImmediate <= s_exeImmediateNext;

  wire[2:0] s_exeLogicControlNext;
  assign s_exeLogicControlNext[0] = (instruction[31:26] == 6'b111000 &&
                                     instruction[10:8] == 3'b000 &&
                                     instruction[3:0] == 4'h3) // AND
                                    ||
                                    (instruction[31:26] == 6'b111000 &&
                                     instruction[10:8] == 3'b000 &&
                                     instruction[3:0] == 4'h5) // XOR
                                    ||
                                    (instruction[31:26] == 6'b101001) // ANDI
                                    ||
                                    (instruction[31:26] == 6'b101011) // XORI
                                    ||
                                    (instruction[31:26] == 6'b111000 &&
                                     instruction[9:8] == 2'b00 &&
                                     instruction[6] == 1'b1 &&
                                     instruction[3:0] == 4'hC) // extend
                                    ?1'b1 : 1'b0;
  assign s_exeLogicControlNext[1] = (instruction[31:26] == 6'b111000 &&
                                     instruction[10:8] == 3'b000 &&
                                     instruction[3:0] == 4'h4) // OR
                                    ||
                                    (instruction[31:26] == 6'b111000 &&
                                     instruction[10:8] == 3'b000 &&
                                     instruction[3:0] == 4'h5) // XOR
                                    ||
                                    (instruction[31:26] == 6'b101101) // MFSPR
                                    ||
                                    (instruction[31:26] == 6'b110000) // MTSPR
                                    ||
                                    (instruction[31:26] == 6'b101010) // ORI
                                    ||
                                    (instruction[31:26] == 6'b101011) // XORI
                                    ||
                                    (instruction[31:26] == 6'b111000 &&
                                     instruction[9:8] == 2'b00 &&
                                     instruction[7] == 1'b1 &&
                                     instruction[3:0] == 4'hC) // extend
                                    ?1'b1 : 1'b0;
  assign s_exeLogicControlNext[2] = (instruction[31:26] == 6'b111000 &&
                                     instruction[9:8] == 2'b00 &&
                                     instruction[3:0] == 4'hC) // extend
                                    ?1'b1 : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeLogicCntrl <= 3'b000;
                             else if (stall == 1'b0) exeLogicCntrl <= s_exeLogicControlNext;
  
  wire [1:0] s_exeSprControlNext;
  assign s_exeSprControlNext[0] = (instruction[31:26] == 6'b101101) ? 1'b1 : 1'b0; //MFSPR
  assign s_exeSprControlNext[1] = (instruction[31:26] == 6'b110000) ? 1'b1 : 1'b0; //MTSPR
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeSprControl <= 2'd0;
                             else if (stall == 1'b0) exeSprControl <= s_exeSprControlNext;

  wire [2:0] s_exeShiftCntrlNext;
  assign s_exeShiftCntrlNext[0] = (instruction[31:26] == 6'b111000 &&
                                   instruction[10:8] == 3'b000 &&
                                   instruction[3:0] == 4'h8 &&
                                   instruction[6] == 1'b1) // shift
                                  ||
                                  (instruction[31:26] == 6'b101110 &&
                                   instruction[10] == 1'b0 &&
                                   instruction[6] == 1'b1) // shift I
                                  ||
                                  (instruction[31:26] == 6'b111000 &&
                                   instruction[9:8] == 2'b00 &&
                                   instruction[3:0] == 4'hE) // CMOV
                                  ? ~s_dataDependencyStall : 1'b0;
  assign s_exeShiftCntrlNext[1] = (instruction[31:26] == 6'b111000 &&
                                   instruction[10:8] == 3'b000 &&
                                   instruction[3:0] == 4'h8 &&
                                   instruction[7] == 1'b1) // shift
                                  ||
                                  (instruction[31:26] == 6'b101110 &&
                                   instruction[10] == 1'b0 &&
                                   instruction[7] == 1'b1) // shift I
                                  ||
                                  (instruction[31:26] == 6'b111000 &&
                                   instruction[9:8] == 2'b00 &&
                                   instruction[3:0] == 4'hE) // CMOV
                                  ||
                                  (instruction[31:26] == 6'b000110 &&
                                   instruction[20:16] == 5'b00000) // MIH
                                  ? ~s_dataDependencyStall : 1'b0;
  assign s_exeShiftCntrlNext[2] = (instruction[31:26] == 6'b111000 &&
                                   instruction[10:8] == 3'b000 &&
                                   instruction[3:0] == 4'h8) // shift
                                  ||
                                  (instruction[31:26] == 6'b101110 &&
                                   instruction[10] == 1'b0) // shift I
                                  ? ~s_dataDependencyStall : 1'b0;
  always @(posedge cpuClock) if (stall == 1'b0) exeShiftCntrl <= s_exeShiftCntrlNext;

  wire e_exeMultNext = (instruction[31:26] == 6'b101100) // MULI
                       ||
                       (instruction[31:26] == 6'b111000 &&
                        instruction[10:8] == 3'b011 &&
                        (instruction[3:0] == 4'b0110 ||
                         instruction[3:0] == 4'b1011)) // MUL 
                       ? 1'b1 : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeMult <= 1'b0;
                             else if (stall == 1'b0) exeMult <= e_exeMultNext;

  wire s_softResetNext = instruction[31:26] == 6'b011101 ? 1'b1 : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeSoftReset <= 1'b0;
                             else if (stall == 1'b0) exeSoftReset <= s_softResetNext;

  wire s_insertNop = s_isJump || s_softResetNext;
  assign insertNop = s_insertNop;
  reg [1:0] s_nopDelayReg;
  wire [1:0] s_nopDelayNext = (stall == 1'b0 && s_dataDependencyStall == 1'b0) ? {s_nopDelayReg[0],s_insertNop | s_isException} : s_nopDelayReg;
  always @(posedge cpuClock) if (cpuReset == 1'b1) s_nopDelayReg <= 2'b00;
                             else s_nopDelayReg <= s_nopDelayNext;

  wire s_isRfe = instruction[31:26] == 6'b001001 ? 1'b1 : 1'b0;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeRfe <= 1'b0;
                             else if (stall == 1'b0) exeRfe <= s_isRfe;
  reg [1:0]  s_rfeDelayReg;
  wire [1:0] s_rfeDelayNext = (stall == 1'b0 && s_dataDependencyStall == 1'b0) ? {s_rfeDelayReg[0],s_isRfe} : s_rfeDelayReg;
  always @(posedge cpuClock) if (cpuReset == 1'b1) s_rfeDelayReg <= 2'b00;
                             else s_rfeDelayReg <= s_rfeDelayNext;
  
  wire [2:0] s_exceptionModeNext = (s_inExcepModeReg == 1'b1 ||
                                    s_nopDelayReg[1] == 1'b1 ||
                                    s_rfeDelayReg != 2'b00 ||
                                    stall == 1'b1) ? 3'b000 :
                                   (validInstruction == 1'b0) ? 3'b001 :
                                   (dCacheError == 1'b1 || s_dCacheErrorReg == 1'b1) ? 3'b010 :
                                   (s_irqRequestReg[3] == 1'b1) ? 3'b011 :
                                   (s_executeNext == 1'b0) ? 3'b100 :
                                   (s_systemCall == 1'b1) ? 3'b101 : 3'b000;
  always @(posedge cpuClock) if (cpuReset == 1'b1) s_exceptionModeReg <= 3'b000;
                             else if (stall == 1'b0) s_exceptionModeReg <= s_exceptionModeNext;
  
  wire s_dCacheErrorNext = s_exceptionModeNext == 3'b010 || cpuReset == 1'b1 ? 1'b0 :
                           stall == 1'b0 && dCacheError == 1'b1 ? 1'b1 : s_dCacheErrorReg;
  always @(posedge cpuClock) s_dCacheErrorReg <= s_dCacheErrorNext;
  
  wire [3:0] s_irqRequestNext;
  assign s_irqRequestNext[3] = s_irqRequestReg[2:1] == 2'b01 ? 1'b1 :
                               s_exceptionModeNext == 3'b011 ? 1'b0 : s_irqRequestReg[3];
  assign s_irqRequestNext[2:0] = {s_irqRequestReg[1:0],irq};
  always @(posedge cpuClock) if (cpuReset == 1'b1) s_irqRequestReg <= 4'h0;
                             else s_irqRequestReg <= s_irqRequestNext;
  
  assign s_isException = (s_inExcepModeReg == 1'b0 &&
                          s_nopDelayReg[1] == 1'b0 &&
                          s_rfeDelayReg == 2'b00 &&
                          (validInstruction == 1'b0 ||
                           s_irqRequestReg[3] == 1'b1 ||
                           s_executeNext == 1'b0 ||
                           dCacheError == 1'b1 ||
                           s_dCacheErrorReg == 1'b1 ||
                           s_systemCall == 1'b1)) ? 1'b1 : 1'b0;
  wire s_inExceptionModeNext = cpuReset == 1'b1 ||
                               (stall == 1'b0 &&
                                (s_rfeDelayReg[1] == 1'b1 ||
                                 s_softResetNext == 1'b1)) 
                               ? 1'b0 :
                               stall == 1'b0 &&
                               s_isException == 1'b1 &&
                               s_dataDependencyStall == 1'b1 ? 1'b1 : s_inExcepModeReg;
  always @(posedge cpuClock) s_inExcepModeReg <= s_inExceptionModeNext;
  
  wire s_flushNext = (cpuReset == 1'b1) ? 1'b0 :
                     (stall == 1'b0 && s_dataDependencyStall == 1'b0) ?
                     s_softResetNext | s_isException | s_isRfe | s_nopDelayReg[0] | s_rfeDelayReg[0] : s_flushReg;
  always @(posedge cpuClock) s_flushReg <= s_flushNext;
  
  // here the forwarding is determined
  wire [1:0] s_forwardCntrlANext = s_regAIdxNext == 5'd0 ? 2'b00 :
                                   (s_regAIdxNext == exeStageWbIndex && exeStageWbWe == 1'b1) ? 2'b01 :
                                   (s_regAIdxNext == memStageWbIndex && memStageWbWe == 1'b1) ? 2'b10 :
                                   (s_regAIdxNext == wbStageWbIndex && wbStageWbWe == 1'b1) ? 2'b11 : 2'b00;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeForwardCntrlA <= 2'b00;
                             else if (stall == 1'b0) exeForwardCntrlA <= s_forwardCntrlANext;

  wire [1:0] s_forwardCntrlBNext = s_regBIdxNext == 5'd0 ? 2'b00 :
                                   (s_regBIdxNext == exeStageWbIndex && exeStageWbWe == 1'b1) ? 2'b01 :
                                   (s_regBIdxNext == memStageWbIndex && memStageWbWe == 1'b1) ? 2'b10 :
                                   (s_regBIdxNext == wbStageWbIndex && wbStageWbWe == 1'b1) ? 2'b11 : 2'b00;
  always @(posedge cpuClock) if (cpuReset == 1'b1) exeForwardCntrlB <= 2'b00;
                             else if (stall == 1'b0) exeForwardCntrlB <= s_forwardCntrlBNext;

  // here part of the custom interface is defined
  wire s_isCustom = (instruction[31:26] == 6'b011100) ? ~s_dataDependencyStall & ~s_isException : 1'b0;
  reg s_isCustomReg;
  always @(posedge cpuClock) if (cpuReset == 1'b1) s_isCustomReg <= 1'b0;
                             else if (stall == 1'b0) s_isCustomReg <= s_isCustom;
  assign exeCustom = s_isCustomReg;
  
  wire s_startNext = ~cpuReset &&
                     ~stall &&
                     ~s_isException &&
                     ~s_dataDependencyStall &&
                     s_isCustom;
  reg s_startReg;
  always @(posedge cpuClock) s_startReg <= s_startNext;
  assign customInstructionStart = s_startReg;
  
  reg s_doneReg;
  wire s_doneNext = cpuReset == 1'b1 || customInstructionDone == 1'b1
                    ? 1'b1 : s_startReg == 1'b1 ? 1'b0 : s_doneReg;
  always @(posedge cpuClock) s_doneReg <= s_doneNext;

  reg s_extendedDoneReg;
  wire s_extendedDoneNext = cpuReset == 1'b1 ? 1'b0 :
                            stall == 1'b1 && customInstructionDone == 1'b1 ? 1'b1 :
                            stall == 1'b0 ? 1'b0 : s_extendedDoneReg;
  always @(posedge cpuClock) s_extendedDoneReg <= s_extendedDoneNext;
  
  assign customInstructionStall = s_isCustomReg == 1'b1 &&
                                  s_extendedDoneReg == 1'b0 &&
                                  (customInstructionDone == 1'b0 ||
                                   s_doneReg == 1'b0) &&
                                  !(customInstructionDone == 1'b1 &&
                                    s_doneReg == 1'b0) ? 1'b1 : 1'b0;
  
  always @(posedge cpuClock)
    if (stall == 1'b0)
      begin
        customInatructionN       <= instruction[7:0];
        customInstructionA       <= instruction[20:16];
        customInstructionB       <= instruction[15:11];
        customInstructionD       <= instruction[25:21];
        customInstructionReadRa  <= instruction[10];
        customInstructionReadRb  <= instruction[9];
        customInstructionWriteRd <= instruction[8];
      end
endmodule
