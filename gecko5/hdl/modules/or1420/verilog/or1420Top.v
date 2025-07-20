module or1420Top #( parameter [31:0] NOP_INSTRUCTION = 32'h1500FFFF)
                  ( input wire         cpuClock,
                                       cpuReset,
                                       irq,
                    
                    output reg         cpuIsStalled,
                    
                    output wire        iCacheReqBus,
                                       dCacheReqBus,
                    input wire         iCacheBusGrant,
                                       dCacheBusGrant,
                                       busErrorIn,
                                       busyIn,
                    output wire        beginTransActionOut,
                    input wire [31:0]  addressDataIn,
                    output wire [31:0] addressDataOut,
                    input wire         endTransactionIn,
                    output wire        endTransactionOut,
                    output wire [3:0]  byteEnablesOut,
                    input wire         dataValidIn,
                    output wire        dataValidOut,
                                       readNotWriteOut,
                    output wire [7:0]  burstSizeOut,
                    
                    output wire        ciStart,
                                       ciReadRa,
                                       ciReadRb,
                                       ciWriteRd,
                    output wire [7:0]  ciN,
                    output wire [4:0]  ciA,
                                       ciB,
                                       ciD,
                    output wire [31:0] ciDataA,
                                       ciDataB,
                    input wire [31:0]  ciResult,
                    input wire         ciDone);

  /*
   *
   * we start with the fetch-stage
   *
   */
  wire        s_fetchBeginTransaction, s_fetchEndTransaction, s_fetchReadNotWrite;
  wire        s_stallFetch, s_fetchStallOut, s_decodeInsertNop;
  wire        s_executeDoJump, s_fetchValidInstruction;
  wire [31:0] s_fetchAddressData, s_fetchInstruction;
  wire [31:2] s_executeJumpTarget, s_fetchLinkAddress, s_fetchProgramCounter;
  wire [3:0]  s_fetchByteEnables;
  wire [7:0]  s_fetchBurstSize;
  
  fetchStage #(.NOP_INSTRUCTION(NOP_INSTRUCTION)) fetch
              (.cpuClock(cpuClock),
               .cpuReset(cpuReset),
               .requestTheBus(iCacheReqBus),
               .busAccessGranted(iCacheBusGrant),
               .busErrorIn(busErrorIn),
               .beginTransactionOut(s_fetchBeginTransaction),
               .addressDataIn(addressDataIn),
               .addressDataOut(s_fetchAddressData),
               .endTransactionIn(endTransactionIn),
               .endTransactionOut(s_fetchEndTransaction),
               .byteEnablesOut(s_fetchByteEnables),
               .dataValidIn(dataValidIn),
               .burstSizeOut(s_fetchBurstSize),
               .readNotWriteOut(s_fetchReadNotWrite),
               .dCacheStall(s_stallFetch),
               .stallOut(s_fetchStallOut),
               .insertNop(s_decodeInsertNop),
               .doJump(s_executeDoJump),
               .jumpTarget(s_executeJumpTarget),
               .linkAddress(s_fetchLinkAddress),
               .programCounter(s_fetchProgramCounter),
               .instruction(s_fetchInstruction),
               .validInstruction(s_fetchValidInstruction));

  /*
   *
   * The decode stage
   *
   */
  wire        s_cpuStall, s_dCacheError, s_dataDependencyStall, s_ciStall, s_decodeUpdateFlags;
  wire        s_decodeInExceptionMode, s_decodeWbWriteEnable, s_executeWbWriteEnable, s_memWbWriteEnable;
  wire        s_decodeLink, s_decodeSoftReset, s_decodeRfe, s_decodeCustom, s_decodeMult, s_memLoadPending;
  wire [4:0]  s_decodeReadAddressA, s_decodeReadAddressB;
  wire [4:0]  s_decodeWbWriteIndex, s_executeWbWriteIndex, s_memWbWriteIndex;
  wire [31:0] s_registerFileDataA, s_registerFileDataB, s_decodeDataA, s_decodeDataB;
  wire [31:2] s_decodeProgramCounter;
  wire [1:0]  s_decodeForwardA, s_decodeForwardB, s_decodeAdderCntrl, s_decodeJumpMode;
  wire [1:0]  s_decodeStoreMode,s_decodeSprControl;
  wire [3:0]  s_decodeFlagMode;
  wire [2:0]  s_decodeLogicCntrl, s_decodeShiftCntrl, s_decodeExceptionMode, s_decodeLoadMode;
  wire [2:0]  s_executeLoadMode;
  wire [15:0] s_decodeImmediate;
  
  decodeStage decode ( .cpuClock(cpuClock),
                       .cpuReset(cpuReset),
                       .stall(s_cpuStall),
                       .irq(irq),
                       .dCacheError(s_dCacheError),
                       .dataDependencyStall(s_dataDependencyStall),
                       .customInstructionStall(s_ciStall),
                       .instruction(s_fetchInstruction),
                       .validInstruction(s_fetchValidInstruction),
                       .programCounter(s_fetchProgramCounter),
                       .insertNop(s_decodeInsertNop),
                       .readAddressA(s_decodeReadAddressA),
                       .readAddressB(s_decodeReadAddressB),
                       .registerDataA(s_registerFileDataA),
                       .registerDataB(s_registerFileDataB),
                       .inExceptionMode(s_decodeInExceptionMode),
                       .exeStageWbIndex(s_decodeWbWriteIndex),
                       .memStageWbIndex(s_executeWbWriteIndex),
                       .wbStageWbIndex(s_memWbWriteIndex),
                       .exeStageWbWe(s_decodeWbWriteEnable),
                       .memStageWbWe(s_executeWbWriteEnable),
                       .wbStageWbWe(s_memWbWriteEnable),
                       .exeProgramCounter(s_decodeProgramCounter),
                       .exePortAData(s_decodeDataA),
                       .exePortBData(s_decodeDataB),
                       .exeForwardCntrlA(s_decodeForwardA),
                       .exeForwardCntrlB(s_decodeForwardB),
                       .exeAdderCntrl(s_decodeAdderCntrl),
                       .exeLogicCntrl(s_decodeLogicCntrl),
                       .exeSprControl(s_decodeSprControl),
                       .exeShiftCntrl(s_decodeShiftCntrl),
                       .exeUpdateFlags(s_decodeUpdateFlags),
                       .exeJumpMode(s_decodeJumpMode),
                       .exeLink(s_decodeLink),
                       .exeFlagMode(s_decodeFlagMode),
                       .exeSoftReset(s_decodeSoftReset),
                       .exeExceptionMode(s_decodeExceptionMode),
                       .exeRfe(s_decodeRfe),
                       .exeImmediate(s_decodeImmediate),
                       .exeCustom(s_decodeCustom),
                       .exeMult(s_decodeMult),
                       .memStoreMode(s_decodeStoreMode),
                       .memLoadMode(s_decodeLoadMode),
                       .memstageLoadMode(s_executeLoadMode),
                       .wbStageLoadPending(s_memLoadPending),
                       .wbWriteIndex(s_decodeWbWriteIndex),
                       .wbWriteEnable(s_decodeWbWriteEnable),
                       .customInstructionStart(ciStart),
                       .customInatructionN(ciN),
                       .customInstructionA(ciA),
                       .customInstructionB(ciB),
                       .customInstructionD(ciD),
                       .customInstructionReadRa(ciReadRa),
                       .customInstructionReadRb(ciReadRb),
                       .customInstructionWriteRd(ciWriteRd),
                       .customInstructionDone(ciDone) );

  /*
   *
   * The execution stage
   *
   */
  reg [31:0]  s_wbDataReg;
  wire [31:0] s_executeWriteData, s_memWriteData, s_exeStoreData;
  wire [1:0]  s_exeStoreMode;
  wire [31:0] s_sprWriteData, s_sprReadData, s_exceptionVector;
  wire [15:0] s_sprIndex;
  wire        s_sprWe, s_exceptionPrefix;
  
  executeStage exe ( .cpuClock(cpuClock),
                     .cpuReset(cpuReset),
                     .stall(s_cpuStall),
                     .doJump(s_executeDoJump),
                     .jumpTarget(s_executeJumpTarget),
                     .linkAddress(s_fetchLinkAddress),
                     .sprDataOut(s_sprWriteData),
                     .sprIndex(s_sprIndex),
                     .sprWe(s_sprWe),
                     .sprDataIn(s_sprReadData),
                     .exceptionPrefix(s_exceptionPrefix),
                     .exceptionVector(s_exceptionVector),
                     .decProgramCounter(s_fetchProgramCounter),
                     .exeProgramCounter(s_decodeProgramCounter),
                     .exePortADataIn(s_decodeDataA),
                     .exePortBDataIn(s_decodeDataB),
                     .exeAdderCntrlIn(s_decodeAdderCntrl),
                     .exeJumpMode(s_decodeJumpMode),
                     .exeSprControl(s_decodeSprControl),
                     .memStoreModeIn(s_decodeStoreMode),
                     .exeLogicCntrl(s_decodeLogicCntrl),
                     .exeShiftCntrl(s_decodeShiftCntrl),
                     .exeExcepMode(s_decodeExceptionMode),
                     .memLoadModeIn(s_decodeLoadMode),
                     .exeFlagMode(s_decodeFlagMode),
                     .wbWriteIndexIn(s_decodeWbWriteIndex),
                     .exeImmediate(s_decodeImmediate),
                     .exeUpdateFlags(s_decodeUpdateFlags),
                     .exeLink(s_decodeLink),
                     .exeSoftReset(s_decodeSoftReset),
                     .exeRfe(s_decodeRfe),
                     .exeCustom(s_decodeCustom),
                     .exeMult(s_decodeMult),
                     .wbWriteEnableIn(s_decodeWbWriteEnable),
                     .exeForwardCntrlA(s_decodeForwardA),
                     .exeForwardCntrlB(s_decodeForwardB),
                     .exeWbData(s_executeWriteData),
                     .memWbData(s_memWriteData),
                     .wbWbData(s_wbDataReg),
                     .memStoreMode(s_exeStoreMode),
                     .memLoadMode(s_executeLoadMode),
                     .memStoreData(s_exeStoreData),
                     .wbWriteData(s_executeWriteData),
                     .wbWriteIndex(s_executeWbWriteIndex),
                     .wbWriteEnable(s_executeWbWriteEnable),
                     .customInstructionDataA(ciDataA),
                     .customInstructionDataB(ciDataB),
                     .customInstructionResult(ciResult),
                     .customInstructionDone(ciDone));

  /*
   *
   * the spr interface
   *
   */
  sprUnit sprs ( .cpuClock(cpuClock),
                 .cpuReset(cpuReset),
                 .stall(s_cpuStall),
                 .sprDataOut(s_sprReadData),
                 .sprIndex(s_sprIndex),
                 .sprWe(s_sprWe),
                 .sprDataIn(s_sprWriteData),
                 .exeExcepMode(s_decodeExceptionMode),
                 .exceptionPrefix(s_exceptionPrefix),
                 .exceptionVector(s_exceptionVector) );


  /*
   *
   * The memory stage
   *
   */
  memoryStage mem ( .cpuClock(cpuClock),
                    .cpuReset(cpuReset),
                    .stall(s_cpuStall),
                    .wbLoadMode(s_executeLoadMode),
                    .wbWriteDataIn(s_executeWriteData),
                    .wbWriteIndexIn(s_executeWbWriteIndex),
                    .wbWriteEnableIn(s_executeWbWriteEnable),
                    .wbStageLoadPending(s_memLoadPending),
                    .wbWriteData(s_memWriteData),
                    .wbWriteIndex(s_memWbWriteIndex),
                    .wbWriteEnable(s_memWbWriteEnable));

  /*
   *
   * The write-back stage
   *
   */
  wire        s_dCacheWriteEnable;
  wire [31:0] s_dCacheWiteData;
  wire [31:0] s_rfWriteData = (s_dCacheWriteEnable == 1'b1) ? s_dCacheWiteData : s_memWriteData;
  wire        s_rfWriteEnable = s_memWbWriteEnable | s_dCacheWriteEnable;
  
  always @(posedge cpuClock) s_wbDataReg <= (s_cpuStall == 1'b0) ? s_rfWriteData : s_wbDataReg;
  
  registerFile regs ( .cpuClock(cpuClock),
                      .stall(s_cpuStall),
                      .inExceptionMode(s_decodeInExceptionMode),
                      .writeEnable(s_rfWriteEnable),
                      .readAddrA(s_decodeReadAddressA),
                      .readAddrB(s_decodeReadAddressB),
                      .writeAddr(s_memWbWriteIndex),
                      .writeData(s_rfWriteData),
                      .dataA(s_registerFileDataA),
                      .dataB(s_registerFileDataB));

  /*
   *
   * The load Store unit
   *
   */
  wire        s_stallLoadStore, s_dCacheStall, s_dCacheBeginTransaction;
  wire        s_dCacheEndTransaction, s_dCacheDataValid, s_dCacheReadNotWrite;
  wire [31:0] s_dCacheAddressData;
  wire [3:0]  s_dCacheByteEnables;
  wire [7:0]  s_dCacheBurstSize;

  dCache loadStore ( .cpuClock(cpuClock),
                     .cpuReset(cpuReset),
                     .iCacheStall(s_stallLoadStore),
                     .stallOut(s_dCacheStall),
                     .dCacheError(s_dCacheError),
                     .storeMode(s_exeStoreMode),
                     .loadMode(s_executeLoadMode),
                     .memoryAddress(s_executeWriteData),
                     .cpuDataIn(s_exeStoreData),
                     .cpuDataOut(s_dCacheWiteData),
                     .weRegister(s_dCacheWriteEnable),
                     .requestTheBus(dCacheReqBus),
                     .busAccessGranted(dCacheBusGrant),
                     .busErrorIn(busErrorIn),
                     .busyIn(busyIn),
                     .beginTransactionOut(s_dCacheBeginTransaction),
                     .addressDataIn(addressDataIn),
                     .addressDataOut(s_dCacheAddressData),
                     .endTransactionIn(endTransactionIn),
                     .endTransactionOut(s_dCacheEndTransaction),
                     .byteEnablesOut(s_dCacheByteEnables),
                     .dataValidIn(dataValidIn),
                     .dataValidOut(s_dCacheDataValid),
                     .burstSizeOut(s_dCacheBurstSize),
                     .readNotWriteOut(s_dCacheReadNotWrite));

  /*
   *
   * The stall signals
   *
   */

  assign s_cpuStall       = s_dCacheStall | s_fetchStallOut | s_ciStall;
  assign s_stallFetch     = s_dCacheStall | s_dataDependencyStall | s_ciStall;
  assign s_stallLoadStore = s_fetchStallOut | s_ciStall;
  
  always @(posedge cpuClock) cpuIsStalled <= s_cpuStall;

  /*
   *
   * Here the bus output signals are defined
   *
   */
  assign beginTransActionOut = s_fetchBeginTransaction | s_dCacheBeginTransaction;
  assign addressDataOut      = s_fetchAddressData | s_dCacheAddressData;
  assign endTransactionOut   = s_fetchEndTransaction | s_dCacheEndTransaction;
  assign byteEnablesOut      = s_fetchByteEnables | s_dCacheByteEnables;
  assign dataValidOut        = s_dCacheDataValid;
  assign burstSizeOut        = s_fetchBurstSize | s_dCacheBurstSize;
  assign readNotWriteOut     = s_fetchReadNotWrite | s_dCacheReadNotWrite;
  
endmodule
