module sdramController #( parameter [31:0] baseAddress = 32'h00000000,
                          parameter        systemClockInHz = 40000000 ) // supports up to 100MHz
                       ( input wire         clock,
                                            clockX2,
                                            reset,
                         input wire [5:0]   memoryDistanceIn,
                         output wire        sdramInitBusy,
                         
                         // here the bus interface is defined
                         input wire         beginTransactionIn,
                                            endTransactionIn,
                                            readNotWriteIn,
                                            dataValidIn,
                                            busErrorIn,
                                            busyIn,
                         input wire [31:0]  addressDataIn,
                         input wire [3:0]   byteEnablesIn,
                         input wire [7:0]   burstSizeIn,
                         output wire        endTransactionOut,
                                            dataValidOut,
                                            busyOut,
                         output reg         busErrorOut,
                         output wire [31:0] addressDataOut,
                         
                         // here the off-chip signals are defined
                         output wire        sdramClk,
                         output reg         sdramCke,
                                            sdramCsN,
                                            sdramRasN,
                                            sdramCasN,
                                            sdramWeN,
                         output reg  [1:0]  sdramDqmN,
                         output reg  [12:0] sdramAddr,
                         output reg  [1:0]  sdramBa,
                         inout wire [15:0]  sdramData);

  localparam [4:0] RESET_STATE = 5'd0, WAIT_100_MICRO = 5'd1, DO_PRECHARGE = 5'd2, WAIT_PRECHARGE = 5'd3, DO_AUTO_REFRESH1 = 5'd4, WAIT_AUTO_REFRESH1 = 5'd5;
  localparam [4:0] DO_AUTO_REFRESH2 = 5'd6, WAIT_AUTO_REFRESH2 = 5'd7, SET_MODE_REG = 5'd8, WAIT_MODE_REG = 5'd9, SET_EXTENDED_MODE_REG = 5'd10, WAIT_EXTENDED_MODE_REG = 5'd11;
  localparam [4:0] IDLE = 5'd12, DO_AUTO_REFRESH = 5'd13, WAIT_AUTO_REFRESH = 5'd14, INIT_READ_WRITE = 5'd15, INIT_READ_BURST1 = 5'd16, WAIT_READ_BURST1 = 5'd17, INIT_READ_BURST2 = 5'd18;
  localparam [4:0] WAIT_READ_BURST2 = 5'd19, WAIT_READ_BURST3 = 5'd20, DO_READ = 5'd21, END_READ_TRANSACTION = 5'd22, INIT_WORD_WRITE = 5'd23, WRITE_PRECHARGE = 5'd24, WRITE_LO = 5'd25;
  localparam [4:0] WAIT_WRITE_LO = 5'd26, WRITE_HI = 5'd27, WAIT_WRITE_PRECHARGE = 5'd28, WAIT_READ_BURST4 = 5'd29, WAIT_WRITE_HI = 5'd30, SECOND_BURST = 5'd31;
  
  localparam [14:0] MODE_REG_VALUE = 15'b000001000110111, EXTENDED_MODE_REG_VALUE = 15'b100000001000000;
  localparam [13:0] HUNDERT_MICRO_COUNT = (systemClockInHz / 10000) - 1;
  localparam SYSTEMCLOCK_IN_MHZ =  systemClockInHz/1000000;
  localparam [13:0] AUTO_REFRESH_DELAY_COUNT  = (80 * SYSTEMCLOCK_IN_MHZ)/1000;
  localparam [13:0] AUTO_REFRESH_PERIOD = ((78125 * SYSTEMCLOCK_IN_MHZ) / 1000) - 1;

  reg [4:0] s_sdramCurrentState, s_sdramNextState;
  reg       s_sdramClkReg;
  reg       s_sdramDataValidReg;
  reg       s_writeDoneReg;
  reg [1:0] s_delayedWriteDoneReg;
  reg [9:0] s_distanceDelayCounterReg;
  wire      s_distanceDelayCounterisZero = s_distanceDelayCounterReg == 10'd0 ? 1'b1 : 1'b0;
  
  /*
   *
   * Here we define the bus interface
   *
   */
  reg s_beginTransactionReg, s_readNotWriteReg, s_transactionActiveReg, s_dataInValidReg;
  reg [1:0]   s_busErrorShiftReg, s_dataOutValidReg;
  reg         s_endTransactionPendingReg, s_endTransactionReg;
  reg         s_readPendingReg;
  reg [3:0]   s_byteEnablesReg;
  reg [31:0]  s_busAddressReg, s_busDataReg, s_dataOutReg;
  reg [7:0]   s_burstSizeReg;
  reg [8:0]   s_writeCountReg;
  wire [31:0] s_readDataOut, s_readData;
  wire        s_readFifoEmpty, s_readFifoFull;
  wire        s_isMyTransaction = (s_busAddressReg[31:25] == baseAddress[31:25]) ? s_transactionActiveReg : 1'b0; // 25 bit address range. baseAddress up to baseAddress + 0x01FF_FFFF
  wire        s_readActive      = s_isMyTransaction & s_readNotWriteReg;
  wire        s_busy            = (s_isMyTransaction == 1'b1 && s_writeDoneReg == 1'b0 && s_readNotWriteReg == 1'b0) ? dataValidIn : 1'b0;
  wire        s_clearReadFifo   = (~s_busErrorShiftReg[1]&s_busErrorShiftReg[0]) | (s_isMyTransaction & s_beginTransactionReg);
  wire        s_readPop         = (s_distanceDelayCounterisZero == 1'b1) ? s_readActive & ~s_readFifoEmpty & ~busyIn : 1'b0;
  wire        s_endTransactionNext = (s_isMyTransaction & busErrorIn == 1'b1) | (s_endTransactionPendingReg & s_readFifoEmpty & ~s_dataOutValidReg[0]);
  wire [8:0]  s_writeCountNext     = (s_isMyTransaction == 1'b0) ? 9'h100 :
                                     (s_isMyTransaction == 1'b1 && s_beginTransactionReg == 1'b1 && s_readNotWriteReg == 1'b0) ? {1'b0,s_burstSizeReg} :
                                     (s_sdramCurrentState == WRITE_PRECHARGE && s_readNotWriteReg == 1'b0) ? s_writeCountReg - 9'd1 : s_writeCountReg;
  reg         s_readPush, s_initBusyReg;
  wire        s_requiresTwoBursts;
  
  assign dataValidOut      = s_dataOutValidReg[1];
  assign addressDataOut    = s_dataOutReg;
  assign endTransactionOut = s_endTransactionReg;
  assign sdramInitBusy     = s_initBusyReg;
  assign busyOut           = s_busy;
  
  always @(posedge clock)
    begin
      s_initBusyReg              <= (reset == 1'b1) ? 1'b1 : (s_sdramCurrentState == IDLE) ? 1'b0 : s_initBusyReg;
      s_endTransactionPendingReg <= (reset == 1'b1 || s_endTransactionNext == 1'b1) ? 1'b0 : (s_sdramCurrentState == END_READ_TRANSACTION) ? 1'b1 : s_endTransactionPendingReg;
      s_endTransactionReg        <= s_endTransactionNext & ~reset;
      s_beginTransactionReg      <= beginTransactionIn;
      s_busErrorShiftReg         <= {s_busErrorShiftReg[0], (s_isMyTransaction & busErrorIn)};
      s_transactionActiveReg     <= (reset == 1'b1 || endTransactionIn == 1'b1) ? 1'b0 : (beginTransactionIn == 1'b1) ? 1'b1 : s_transactionActiveReg;
      s_readNotWriteReg          <= (beginTransactionIn == 1'b1) ? readNotWriteIn : s_readNotWriteReg;
      s_byteEnablesReg           <= (beginTransactionIn == 1'b1) ? byteEnablesIn : s_byteEnablesReg;
      s_busAddressReg            <= (beginTransactionIn == 1'b1) ? addressDataIn : s_busAddressReg;
      s_burstSizeReg             <= (beginTransactionIn == 1'b1) ? burstSizeIn : s_burstSizeReg;
      s_dataInValidReg           <= (s_isMyTransaction == 1'b1 && ~(s_delayedWriteDoneReg[0] == 1'b1 || s_sdramCurrentState == WRITE_PRECHARGE) && 
                                     s_readNotWriteReg == 1'b0 && s_writeCountReg[8] == 1'b0) ? dataValidIn : 1'b0;
      s_busDataReg               <= (dataValidIn == 1'b1) ? addressDataIn : s_busDataReg;
      s_writeCountReg            <= s_writeCountNext;
      busErrorOut                <= (reset == 1'b1 || s_isMyTransaction == 1'b0) ? 1'b0 : s_readFifoFull;
      s_dataOutValidReg[0]       <= (busyIn == 1'b1) ? s_dataOutValidReg[0] : s_readPop;
      s_dataOutValidReg[1]       <= (reset == 1'b1) ? 1'b0 : (busyIn == 1'b0) ? s_dataOutValidReg[0] : s_dataOutValidReg[1];
      s_dataOutReg               <= (reset == 1'b1) ? 32'd0 : (busyIn == 1'b1) ? s_dataOutReg : s_dataOutValidReg[0] == 1'b1 ? s_readDataOut : 32'd0;
      s_readPendingReg           <= (reset == 1'b1 || s_sdramCurrentState == SECOND_BURST || (s_sdramCurrentState == INIT_READ_WRITE && s_requiresTwoBursts == 1'd0)) ? 1'b0 :
                                    (s_beginTransactionReg == 1'b1 && s_isMyTransaction == 1'b1 && s_readNotWriteReg == 1'b1) ? 1'b1 : s_readPendingReg;
    end
  
  sdramFifo buffer ( .clock(clock),
                     .reset(reset),
                     .clearReadFifo(s_clearReadFifo),
                     .readPush(s_readPush),
                     .readPop(s_readPop),
                     .readEmpty(s_readFifoEmpty),
                     .readFull(s_readFifoFull),
                     .readDataIn(s_readData),
                     .readDataOut(s_readDataOut));
  /*
   *
   * Here we define some read control signals
   *
   */
  wire [8:0] s_nrOfWordsLeft = 9'd256 - {1'b0,s_busAddressReg[9:2]};
  wire [8:0] s_realBurstSize = {1'd0,s_burstSizeReg} + 9'd1;
  wire [8:0] s_burstSize1 = (s_requiresTwoBursts == 1'b1) ? s_nrOfWordsLeft - 9'd1 : s_realBurstSize - 9'd1;
  wire [8:0] s_burstSize2 = (s_requiresTwoBursts == 1'b1) ? s_realBurstSize - s_nrOfWordsLeft - 9'd1 : 9'd0;
  
  assign s_requiresTwoBursts = (s_realBurstSize > s_nrOfWordsLeft) ? 1'b1 : 1'b0;
  /*
   *
   * Here we define the memory distance
   *
   */
  wire [5:0] s_correctedMemoryDistanceIn = (memoryDistanceIn < 6'd2) ? 6'd0 : (memoryDistanceIn == 6'd2) ? 6'd3 : memoryDistanceIn - 6'd1; // dirty bug fix
  wire [9:0] s_distanceDelayCounterNext = (s_beginTransactionReg == 1'b1 && s_isMyTransaction == 1'b1) ? {4'd0,s_correctedMemoryDistanceIn} + {3'd0,memoryDistanceIn, 1'b0} + {2'd0,memoryDistanceIn, 2'd0} :
                                          (s_readPop == 1'b1) ? {4'd0,memoryDistanceIn} :
                                          (s_distanceDelayCounterReg != 10'd0) ? s_distanceDelayCounterReg - 10'd1 : s_distanceDelayCounterReg;
  
  
  always @(posedge clock) 
    begin
      s_writeDoneReg = (reset == 1'b1) ? 1'b0 : (s_distanceDelayCounterisZero == 1'b1 && s_sdramCurrentState == WRITE_PRECHARGE) ? 1'b1 : s_delayedWriteDoneReg[1] & ~s_delayedWriteDoneReg[0];
      s_distanceDelayCounterReg <= (reset == 1'b1) ? 10'd0 : s_distanceDelayCounterNext;
      s_delayedWriteDoneReg[0]  <= (reset == 1'b1 || s_distanceDelayCounterReg == 10'd1 || s_distanceDelayCounterReg == 10'd0) ? 1'b0 :
                                   (s_sdramCurrentState == WRITE_PRECHARGE) ? 1'b1 : s_delayedWriteDoneReg[0];
      s_delayedWriteDoneReg[1]  <= s_delayedWriteDoneReg[0];
    end


  /*
   *
   * Here we define the row and column address
   *
   */
  reg [8:0]   s_columnAddressReg;
  reg [14:0]  s_rowAddressReg;
  wire [8:0]  s_columnAddressNext = (s_beginTransactionReg == 1'b1 && s_isMyTransaction == 1'b1 && s_sdramClkReg == 1'b1) ? {s_busAddressReg[9:2],1'b0} :
                                    ((s_sdramCurrentState == WAIT_WRITE_LO || s_sdramCurrentState == WAIT_WRITE_HI || s_sdramDataValidReg == 1'b1) && s_sdramClkReg == 1'b1) ? s_columnAddressReg + 9'd1 : 
                                    s_columnAddressReg;
  wire [14:0] s_rowAddressNext = (s_beginTransactionReg == 1'b1 && s_isMyTransaction == 1'b1 && s_sdramClkReg == 1'b1) ? s_busAddressReg[24:10] : 
                                 ((s_sdramCurrentState == WAIT_WRITE_LO || s_sdramCurrentState == WAIT_WRITE_HI || s_sdramDataValidReg == 1'b1) && 
                                  s_sdramClkReg == 1'b1 && s_columnAddressReg == 9'b111111111) ? s_rowAddressReg + 9'd1 : s_rowAddressReg;
  
  always @(posedge clockX2)
    begin
      s_columnAddressReg <= s_columnAddressNext;
      s_rowAddressReg    <= s_rowAddressNext;
    end

  /*
   *
   * Here we define the state machine and the required counters for refresh and wait
   *
   */
  reg [13:0]  s_counterValue, s_refreshCounter;
  wire        s_shortCountIsZero;
  wire        s_loadCounter = (s_sdramCurrentState == RESET_STATE ||
                               s_sdramCurrentState == DO_AUTO_REFRESH ||
                               s_sdramCurrentState == DO_AUTO_REFRESH1 ||
                               s_sdramCurrentState == DO_AUTO_REFRESH2 ) ? 1'b1 : 1'b0;
  wire        s_counterIsZero = (s_counterValue == 14'd0) ? 1'b1 : 1'b0;
  wire [13:0] s_nextCounterValue = (s_loadCounter == 1'b1 && s_sdramCurrentState == RESET_STATE) ? HUNDERT_MICRO_COUNT :
                                   (s_loadCounter == 1'b1) ? AUTO_REFRESH_DELAY_COUNT : 
                                   (s_counterIsZero == 1'b1) ? s_counterValue : s_counterValue - 13'd1;
  wire        s_refreshCounterZero = (s_refreshCounter == 14'd0) ? 1'd1 : 1'd0;
  wire [13:0] s_nextRefreshCounterValue = (s_sdramCurrentState == DO_AUTO_REFRESH || s_sdramCurrentState == DO_AUTO_REFRESH2) ? AUTO_REFRESH_PERIOD :
                                          (s_refreshCounterZero == 1'b1) ? s_refreshCounter : s_refreshCounter - 14'd1;

  always @*
    case (s_sdramCurrentState)
      RESET_STATE            : s_sdramNextState <= WAIT_100_MICRO;
      WAIT_100_MICRO         : s_sdramNextState <= (s_counterIsZero == 1'b1) ? DO_PRECHARGE : WAIT_100_MICRO;
      DO_PRECHARGE           : s_sdramNextState <= WAIT_PRECHARGE;
      WAIT_PRECHARGE         : s_sdramNextState <= DO_AUTO_REFRESH1;
      DO_AUTO_REFRESH        : s_sdramNextState <= WAIT_AUTO_REFRESH;
      WAIT_AUTO_REFRESH      : s_sdramNextState <= (s_counterIsZero == 1'b1) ? IDLE : WAIT_AUTO_REFRESH;
      DO_AUTO_REFRESH1       : s_sdramNextState <= WAIT_AUTO_REFRESH1;
      WAIT_AUTO_REFRESH1     : s_sdramNextState <= (s_counterIsZero == 1'b1) ? DO_AUTO_REFRESH2 : WAIT_AUTO_REFRESH1;
      DO_AUTO_REFRESH2       : s_sdramNextState <= WAIT_AUTO_REFRESH2;
      WAIT_AUTO_REFRESH2     : s_sdramNextState <= (s_counterIsZero == 1'b1) ? SET_MODE_REG : WAIT_AUTO_REFRESH2;
      SET_MODE_REG           : s_sdramNextState <= WAIT_MODE_REG;
      WAIT_MODE_REG          : s_sdramNextState <= SET_EXTENDED_MODE_REG;
      SET_EXTENDED_MODE_REG  : s_sdramNextState <= WAIT_EXTENDED_MODE_REG;
      IDLE                   : s_sdramNextState <= (s_refreshCounterZero == 1'd1) ? DO_AUTO_REFRESH : 
                                                   (s_dataInValidReg == 1'b1 || s_readPendingReg == 1'd1) ? INIT_READ_WRITE : IDLE;
      INIT_READ_WRITE        : s_sdramNextState <= INIT_READ_BURST1;
      INIT_READ_BURST1       : s_sdramNextState <= (s_dataInValidReg == 1'b1) ? INIT_WORD_WRITE : WAIT_READ_BURST1;
      WAIT_READ_BURST1       : s_sdramNextState <= INIT_READ_BURST2;
      INIT_READ_BURST2       : s_sdramNextState <= WAIT_READ_BURST2;
      WAIT_READ_BURST2       : s_sdramNextState <= WAIT_READ_BURST3;
      WAIT_READ_BURST3       : s_sdramNextState <= WAIT_READ_BURST4;
      WAIT_READ_BURST4       : s_sdramNextState <= DO_READ;
      DO_READ                : s_sdramNextState <= (s_shortCountIsZero == 1'b0) ? DO_READ :
                                                   (s_readPendingReg == 1'b1 && s_requiresTwoBursts == 1'b1) ? WRITE_PRECHARGE : END_READ_TRANSACTION;
      END_READ_TRANSACTION   : s_sdramNextState <= WRITE_PRECHARGE;
      WRITE_PRECHARGE        : s_sdramNextState <= WAIT_WRITE_PRECHARGE;
      WAIT_WRITE_PRECHARGE   : s_sdramNextState <= (s_readPendingReg == 1'b1 && s_requiresTwoBursts == 1'b1) ? SECOND_BURST : IDLE;
      SECOND_BURST           : s_sdramNextState <= INIT_READ_WRITE;
      INIT_WORD_WRITE        : s_sdramNextState <= (s_byteEnablesReg[1:0] == 2'd0) ? WAIT_WRITE_LO : WRITE_LO;
      WRITE_LO               : s_sdramNextState <= WAIT_WRITE_LO;
      WAIT_WRITE_LO          : s_sdramNextState <= (s_byteEnablesReg[3:2] == 2'd0) ? WRITE_PRECHARGE : WRITE_HI;
      WRITE_HI               : s_sdramNextState <= WAIT_WRITE_HI;
      WAIT_WRITE_HI          : s_sdramNextState <= WRITE_PRECHARGE;
      default                : s_sdramNextState <= IDLE;
    endcase
  
  always @(posedge clock)
    begin
      s_counterValue       <= s_nextCounterValue;
      s_refreshCounter     <= s_nextRefreshCounterValue;
    end
  
  always @(posedge clockX2) s_sdramCurrentState  <= (reset == 1'b1) ? RESET_STATE : (s_sdramClkReg == 1'b1) ? s_sdramNextState : s_sdramCurrentState;

  /*
   *
   * Here we define the "short (16-bit word)" counter
   *
   */
  reg [8:0] s_shortCountReg;
  wire s_sheduleReadAbort = (s_shortCountReg == 9'd1 && s_sdramCurrentState == DO_READ && s_burstSizeReg != 8'hFF) ? 1'b1 : 1'b0;
  assign s_shortCountIsZero = (s_shortCountReg == 9'd0) ? 1'b1 : 1'b0;
  wire [8:0] s_shortCountNext = (s_sdramCurrentState == INIT_READ_BURST2 && (s_readPendingReg == 1'b1 || s_requiresTwoBursts == 1'b0)) ? {s_burstSize1[7:0],1'b1} : 
                                (s_sdramCurrentState == INIT_READ_BURST2) ? {s_burstSize2[7:0],1'b1} : 
                                (s_sdramDataValidReg == 1'b1 && s_shortCountIsZero == 1'b0) ? s_shortCountReg - 9'd1 : s_shortCountReg;
  
  always @(posedge clockX2) s_shortCountReg <= (reset == 1'b1) ? 9'd0 : (s_sdramClkReg == 1'b1) ? s_shortCountNext : s_shortCountReg;
 
  /*
   *
   * Here we define the sdram interface
   *
   */
  reg [15:0] s_sdramDataReg, s_wordLoReg, s_wordHiReg, s_sdramDataOutReg;
  reg [32:0] s_dataToRamReg;
  reg  s_sdramEnableDataOutReg;
  wire s_nCs    = (s_sdramCurrentState == RESET_STATE || s_sdramCurrentState == WAIT_100_MICRO) ? 1'b1 : 1'b0;
  wire s_nRas   = (s_sdramCurrentState == DO_PRECHARGE ||
                   s_sdramCurrentState == WRITE_PRECHARGE ||
                   s_sdramCurrentState == DO_AUTO_REFRESH ||
                   s_sdramCurrentState == DO_AUTO_REFRESH1 ||
                   s_sdramCurrentState == DO_AUTO_REFRESH2 ||
                   s_sdramCurrentState == SET_MODE_REG ||
                   s_sdramCurrentState == SET_EXTENDED_MODE_REG ||
                   s_sdramCurrentState == INIT_READ_BURST1) ? 1'b0 : 1'b1;
  wire s_nCas   = (s_sdramCurrentState == DO_AUTO_REFRESH ||
                   s_sdramCurrentState == DO_AUTO_REFRESH1 ||
                   s_sdramCurrentState == DO_AUTO_REFRESH2 ||
                   s_sdramCurrentState == SET_MODE_REG ||
                   s_sdramCurrentState == SET_EXTENDED_MODE_REG ||
                   s_sdramCurrentState == INIT_READ_BURST2 ||
                   s_sdramCurrentState == WRITE_LO ||
                   s_sdramCurrentState == WRITE_HI) ? 1'b0 : 1'b1;
  wire s_nWe    = (s_sdramCurrentState == DO_PRECHARGE ||
                   s_sdramCurrentState == WRITE_PRECHARGE ||
                   s_sdramCurrentState == SET_MODE_REG ||
                   s_sdramCurrentState == SET_EXTENDED_MODE_REG ||
                   s_sdramCurrentState == WRITE_LO ||
                   s_sdramCurrentState == WRITE_HI ||
                   s_sheduleReadAbort == 1'b1) ? 1'b0 : 1'b1;
  wire [1:0] s_bA  = (s_sdramCurrentState == SET_MODE_REG) ? MODE_REG_VALUE[14:13] :
                     (s_sdramCurrentState == SET_EXTENDED_MODE_REG) ? EXTENDED_MODE_REG_VALUE[14:13] :
                     (s_sdramCurrentState == INIT_READ_BURST1 ||
                      s_sdramCurrentState == INIT_READ_BURST2 ||
                      s_sdramCurrentState == WRITE_LO ||
                      s_sdramCurrentState == WRITE_HI) ? s_rowAddressReg[14:13] : 2'd0;
  wire [1:0] s_bS  = (s_sdramCurrentState == WRITE_LO) ? s_byteEnablesReg[1:0] :
                     (s_sdramCurrentState == WRITE_HI) ? s_byteEnablesReg[3:2] : 2'b11;
  wire [12:0] s_address = (s_sdramCurrentState == DO_PRECHARGE ||
                           s_sdramCurrentState == WRITE_PRECHARGE ) ? 13'b0010000000000 :
                          (s_sdramCurrentState == SET_MODE_REG) ? MODE_REG_VALUE[12:0] :
                          (s_sdramCurrentState == SET_EXTENDED_MODE_REG) ? EXTENDED_MODE_REG_VALUE[12:0] :
                          (s_sdramCurrentState == INIT_READ_BURST1) ? s_rowAddressReg[12:0] :
                          (s_sdramCurrentState == INIT_READ_BURST2 ||
                           s_sdramCurrentState == WRITE_LO ||
                           s_sdramCurrentState == WRITE_HI) ? {4'd0,s_columnAddressReg} : 13'd0;
  wire [15:0] s_sdramDataOut = (s_sdramCurrentState == WRITE_HI) ? s_dataToRamReg[31:16] : s_dataToRamReg[15:0];
  wire        s_sdramDataOutValid = (s_sdramCurrentState == WRITE_LO || s_sdramCurrentState == WRITE_HI) ? 1'b1 : 1'b0;
  
  assign sdramClk = s_sdramClkReg;
  assign s_readData = {s_wordHiReg,s_wordLoReg};
  assign sdramData = (s_sdramEnableDataOutReg == 1'b1) ? s_sdramDataOutReg : {16{1'bZ}};
  
  always @(posedge clock)
    begin
      s_wordLoReg            <= (s_sdramDataValidReg == 1'b1 && s_shortCountReg[0] == 1'b1) ? s_sdramDataReg : s_wordLoReg;
      s_wordHiReg            <= (s_sdramDataValidReg == 1'b1 && s_shortCountReg[0] == 1'b0) ? s_sdramDataReg : s_wordHiReg;
      s_readPush             <= (reset == 1'd1) ? 1'b0 : s_sdramDataValidReg & ~s_shortCountReg[0];
    end
  
  always @(posedge clockX2)
    begin
      s_sdramClkReg       <= (reset == 1'b1) ? 1'b1 : ~s_sdramClkReg;
      sdramCke            <= ~reset;
      s_sdramDataReg      <= (s_sdramCurrentState == DO_READ && s_sdramClkReg == 1'b0) ? sdramData : s_sdramDataReg;
      s_sdramDataValidReg <= (reset == 1'b1) ? 1'b0 : (s_sdramCurrentState == DO_READ && s_sdramClkReg == 1'b1) ? ~s_shortCountIsZero : (s_sdramClkReg == 1'b1) ? 1'b0 : s_sdramDataValidReg;
      s_dataToRamReg      <= (reset == 1'b1) ? 32'd0 : (s_sdramCurrentState == INIT_WORD_WRITE && s_sdramClkReg == 1'b1) ? s_busDataReg : s_dataToRamReg;
      if (reset == 1'b1)
        begin
          sdramCsN                <= 1'b1;
          sdramRasN               <= 1'b1;
          sdramCasN               <= 1'b1;
          sdramWeN                <= 1'b1;
          sdramBa                 <= 2'd0;
          sdramDqmN               <= 2'd0;
          sdramAddr               <= 13'd0;
          s_sdramEnableDataOutReg <= 1'd0;
        end
      else if (s_sdramClkReg == 1'b1)
        begin
          sdramCsN                <= s_nCs;
          sdramRasN               <= s_nRas;
          sdramCasN               <= s_nCas;
          sdramWeN                <= s_nWe;
          sdramBa                 <= s_bA;
          sdramDqmN               <= ~s_bS;
          sdramAddr               <= s_address;
          s_sdramEnableDataOutReg <= s_sdramDataOutValid;
          s_sdramDataOutReg       <= s_sdramDataOut;
        end
    end
endmodule
