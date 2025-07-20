module fetchStage #(parameter [31:0] NOP_INSTRUCTION = 32'h1500FFFF)
                   (input wire         cpuClock,
                                       cpuReset,
                    
                    output wire        requestTheBus,
                    input wire         busAccessGranted,
                                       busErrorIn,
                    output wire        beginTransactionOut,
                    input wire [31:0]  addressDataIn,
                    output wire [31:0] addressDataOut,
                    input wire         endTransactionIn,
                    output wire        endTransactionOut,
                    output wire [3:0]  byteEnablesOut,
                    input wire         dataValidIn,
                    output wire [7:0]  burstSizeOut,
                    output wire        readNotWriteOut,
                    
                    input wire         dCacheStall,
                    output wire        stallOut,
                    input wire         insertNop,
                                       doJump,
                    input wire [31:2]  jumpTarget,
                    output wire [31:2] linkAddress,
                                       programCounter,
                    output reg [31:0]  instruction,
                    output reg         validInstruction);

  /*
   *
   * this fetch-stage contains a 2k direct mapped cache with 64bytes cache-lines
   *
   */

  localparam [31:0] RESET_VECTOR      = 32'hF0000030;

  localparam [2:0] IDLE               = 3'd0;
  localparam [2:0] REQUEST_CACHE_LINE = 3'd1;
  localparam [2:0] WAIT_CACHE_LINE    = 3'd2;
  localparam [2:0] UPDATE_TAG         = 3'd3;
  localparam [2:0] LOOKUP             = 3'd4;
  
  localparam [2:0] NOP              = 3'd0;
  localparam [2:0] REQUEST_BUS      = 3'd1;
  localparam [2:0] INIT_TRANSACTION = 3'd2;
  localparam [2:0] WAIT_BURST       = 3'd3;
  localparam [2:0] SIGNAL_DONE      = 3'd4;
  localparam [2:0] BUS_ERROR        = 3'd5;
  
  reg [2:0]  s_stateReg, s_busStateReg;
  reg [3:0]  s_burstCountReg;
  reg        s_stallReg, s_dataInValidReg, s_busErrorReg;
  reg [31:0] s_dataInReg, s_fetchedInstructionReg;
  wire       s_stall = dCacheStall | s_stallReg;
  
  /*
   *
   * Here the program counter is defined
   *
   */
  reg [31:2] s_programCounterReg, s_pcReg;
  
  wire [31:2] s_incrementedProgramCounter = s_pcReg + 30'd1;
  wire [31:2] s_programCounterNext = (doJump == 1'b1) ? jumpTarget :
                                     (insertNop == 1'b1) ? s_pcReg : s_incrementedProgramCounter;
  
  assign linkAddress    = s_incrementedProgramCounter;
  assign programCounter = s_programCounterReg;
  
  always @(posedge cpuClock) 
    begin
      s_pcReg             <= (cpuReset == 1'b1) ? RESET_VECTOR[31:2] :
                             (s_stall == 1'b0) ? s_programCounterNext : s_pcReg;
      s_programCounterReg <= (s_stall == 1'b0) ? s_pcReg : s_programCounterReg;
    end
  
  /*
   *
   * Here all cache related signals are defined
   *
   */
  reg [31:0]   s_dataMemory [511:0];
  reg [31:0]   s_validBits, s_instruction;
  reg [31:11]  s_tagMemory [31:0];
  reg          s_hitReg;
  wire         s_stallHit = (s_stateReg == LOOKUP) ? 1'b0 : s_stall;
  wire         s_weTag    = (s_stateReg == UPDATE_TAG) ? 1'b1 : 1'b0;
  wire [31:6]  s_lookupAddress = (s_stallReg == 1'b0) ? s_programCounterNext[31:6] :
                                 (s_stateReg == LOOKUP) ? s_pcReg[31:6] : s_programCounterReg[31:6];
  wire [8:0]   s_dataAddress = (s_dataInValidReg == 1'b1) ? {s_programCounterReg[10:6], s_burstCountReg} :
                               (s_stateReg == LOOKUP || s_stall == 1'b1) ? s_pcReg[10:2] : s_programCounterNext[10:2];
  wire [4:0]   s_index = s_lookupAddress[10:6];
  wire [31:11] s_newTag = s_lookupAddress[31:11];
  wire         s_selectedValid = s_validBits[s_index];
  wire [31:11] s_selectedTag = s_tagMemory[s_index];
  wire         s_hit = (s_selectedTag == s_lookupAddress[31:11]) ? s_selectedValid : 1'b0;
  
  genvar n;
  
  generate
    for (n = 0 ; n < 32 ; n = n + 1)
      begin:validBits
        always @(posedge cpuClock) 
          begin
            if (cpuReset == 1'b1) s_validBits[n] <= 1'b0;
            else if (s_weTag == 1'b1 && n == s_index) s_validBits[n] <= 1'b1;
          end
      end
  endgenerate
  
  always @(posedge cpuClock)
    begin
      s_hitReg <= (cpuReset == 1'b1) ? 1'b0 : (s_stallHit == 1'b0) ? s_hit : s_hitReg;
      if (s_weTag == 1'b1) s_tagMemory[s_index] = s_newTag;
    end
  
  always @(posedge cpuClock)
    begin
      if (s_dataInValidReg == 1'b1) s_dataMemory[s_dataAddress] <= {s_dataInReg[7:0], s_dataInReg[15:8], s_dataInReg[23:16], s_dataInReg[31:24]};
      s_instruction <= s_dataMemory[s_dataAddress];
    end

  /*
   *
   * Here the stall related signals are defined
   *
   */
  reg s_delayedResetReg, s_insertNopReg;
  
  assign stallOut = s_stallReg | s_delayedResetReg;
  
  always @(posedge cpuClock) 
    begin
      s_delayedResetReg <= cpuReset;
      s_stallReg        <= (s_stateReg == LOOKUP || cpuReset == 1'b1) ? 1'b0 :
                           (s_hitReg == 1'b0 && dCacheStall == 1'b0) ? 1'b1 : s_stallReg;
      s_insertNopReg    <= (cpuReset == 1'b1) ? 1'b0 : (s_stall == 1'b0) ? insertNop : s_insertNopReg;
    end
  
  /*
   *
   * Here the instruction related signals are defined
   *
   */
  wire        s_ackClBus = (s_busStateReg == SIGNAL_DONE) ? 1'b1 : 1'b0;
  wire        s_nextValid = ~(s_busErrorReg & s_ackClBus);
  wire [31:0] s_nextInstruction = ((s_stateReg == IDLE && s_insertNopReg == 1'b1) || cpuReset == 1'b1 || s_delayedResetReg == 1'b1) ? NOP_INSTRUCTION :
                                  (s_ackClBus == 1'b1) ? s_fetchedInstructionReg : s_instruction;

  always @(posedge cpuClock)
    if (s_stall == 1'b0 || s_ackClBus == 1'b1 || cpuReset == 1'b1 || s_delayedResetReg == 1'b1) 
      begin
        validInstruction <= s_nextValid;
        instruction      <= s_nextInstruction;
      end

  /*
   *
   * Here the main state machine is defined
   *
   */
  reg [2:0] s_nextState;
  
  always @*
    case (s_stateReg)
      IDLE               : s_nextState <= (s_stallReg == 1'b1) ? REQUEST_CACHE_LINE : IDLE;
      REQUEST_CACHE_LINE : s_nextState <= WAIT_CACHE_LINE;
      WAIT_CACHE_LINE    : s_nextState <= (s_ackClBus == 1'b1) ? UPDATE_TAG : WAIT_CACHE_LINE;
      UPDATE_TAG         : s_nextState <= LOOKUP;
      default            : s_nextState <= IDLE;
    endcase
  
  always @(posedge cpuClock) s_stateReg <= (cpuReset == 1'b1) ? IDLE : s_nextState;

  /*
   *
   * Here the bus related Signals are defined
   *
   */
  
  reg [2:0] s_nextBusState;
  
  assign requestTheBus       = (s_busStateReg == REQUEST_BUS) ? 1'b1 : 1'b0;
  assign beginTransactionOut = (s_busStateReg == INIT_TRANSACTION) ? 1'b1 : 1'b0;
  assign addressDataOut      = (s_busStateReg == INIT_TRANSACTION) ? {s_programCounterReg[31:6],6'd0} : 32'd0;
  assign byteEnablesOut      = (s_busStateReg == INIT_TRANSACTION) ? 4'hF : 4'd0;
  assign burstSizeOut        = (s_busStateReg == INIT_TRANSACTION) ? 8'h0F: 8'd0;
  assign readNotWriteOut     = (s_busStateReg == INIT_TRANSACTION) ? 1'b1 : 1'b0;
  assign endTransactionOut   = (s_busStateReg == BUS_ERROR) ? 1'b1 : 1'b0;
  
  always @*
    case (s_busStateReg)
      NOP              : s_nextBusState <= (s_stateReg == REQUEST_CACHE_LINE) ? REQUEST_BUS : NOP;
      REQUEST_BUS      : s_nextBusState <= (busAccessGranted == 1'b1) ? INIT_TRANSACTION : REQUEST_BUS;
      INIT_TRANSACTION : s_nextBusState <= WAIT_BURST;
      WAIT_BURST       : s_nextBusState <= (busErrorIn == 1'b1) ? BUS_ERROR:
                                           (endTransactionIn == 1'b1) ? SIGNAL_DONE : WAIT_BURST;
      BUS_ERROR        : s_nextBusState <= SIGNAL_DONE;
      default          : s_nextBusState <= IDLE;
    endcase

  always @(posedge cpuClock)
    begin
      s_dataInReg             <= (s_busStateReg == WAIT_BURST) ? addressDataIn : 32'd0;
      s_dataInValidReg        <= (s_busStateReg == WAIT_BURST) ? dataValidIn : 1'b0;
      s_burstCountReg         <= (s_busStateReg == NOP) ? 4'd0 : (s_dataInValidReg == 1'b1) ? s_burstCountReg + 4'd1 : s_burstCountReg;
      s_fetchedInstructionReg <= (s_dataInValidReg == 1'b1 && s_burstCountReg == s_programCounterReg[5:2]) ? {s_dataInReg[7:0], s_dataInReg[15:8], s_dataInReg[23:16], s_dataInReg[31:24]} :
                                 s_fetchedInstructionReg;
      s_busErrorReg           <= (cpuReset == 1'b1 || s_busStateReg == INIT_TRANSACTION) ? 1'b0 :
                                 (s_busStateReg == BUS_ERROR) ? 1'b1 : s_busErrorReg;
      s_busStateReg           <= (cpuReset == 1'b1) ? NOP : s_nextBusState;
    end
endmodule
