module dCache ( input wire         cpuClock,
                                   cpuReset,
                                   iCacheStall,
                output wire        stallOut,
                                   dCacheError,

                input wire [1:0]   storeMode,
                input wire [2:0]   loadMode,
                input wire [31:0]  memoryAddress,
                                   cpuDataIn,
                output reg [31:0]  cpuDataOut,
                output wire        weRegister,
                
                                   requestTheBus,
                input wire         busAccessGranted,
                                   busErrorIn,
                                   busyIn,
                output wire        beginTransactionOut,
                input wire [31:0]  addressDataIn,
                output wire [31:0] addressDataOut,
                input wire         endTransactionIn,
                output wire        endTransactionOut,
                output wire [3:0]  byteEnablesOut,
                input wire         dataValidIn,
                output wire        dataValidOut,
                output wire [7:0]  burstSizeOut,
                output wire        readNotWriteOut );

  localparam [1:0] IDLE            = 2'd0;
  localparam [1:0] REQUEST_ACTION  = 2'd1;
  localparam [1:0] WAIT_FOR_ACTION = 2'd2;
  localparam [1:0] SIGNAL_DONE     = 2'd3;
  
  localparam [2:0] NOOP             = 3'd0;
  localparam [2:0] REQUEST_BUS      = 3'd1;
  localparam [2:0] INIT_TRANSACTION = 3'd2;
  localparam [2:0] WAIT_READ        = 3'd3;
  localparam [2:0] BUS_ERROR        = 3'd4;
  localparam [2:0] SIG_DONE         = 3'd5;
  localparam [2:0] DO_WRITE         = 3'd6;
  localparam [2:0] END_WRITE        = 3'd7;

  reg [1:0]  s_stateReg;
  reg [2:0]  s_busStateReg;
  reg        s_busErrorReg;
  reg [31:0] s_fetchedDataReg;
  /*
   *
   * This d-cache has no caching functionality and contains an SPM of 4 kByte
   * at address 0xC0000000
   *
   */
  localparam [31:12] SPM_BASE = 20'hC0000;
  
  /*
   * Here the stall related signals are defined
   *
   */
  reg  s_stallReg;
  wire s_stall = iCacheStall | s_stallReg;
  wire s_stallNext = (cpuReset == 1'b1 || s_stateReg == SIGNAL_DONE) ? 1'b0 :
                     ((loadMode != 3'd0 || storeMode != 2'd0) && 
                      memoryAddress[31:13] != SPM_BASE[31:13] && iCacheStall == 1'b0) ? 1'b1 : s_stallReg;
  
  assign stallOut = s_stallReg;

  always @(posedge cpuClock) s_stallReg <= s_stallNext;
  
  /*
   *
   * here the cache error is defined
   *
   */
  reg        s_cacheErrorReg;
  reg [2:0]  s_loadModeReg;
  wire       s_busActionDone = (s_busStateReg == SIG_DONE) ? 1'b1 : 1'b0;
  
  assign weRegister  = (s_loadModeReg != 3'd0 && s_cacheErrorReg == 1'b0 && s_stall == 1'b0) ? 1'b1 : 1'b0;
  assign dCacheError = s_cacheErrorReg;
  
  always @(posedge cpuClock)
    begin
      s_loadModeReg   <= (cpuReset == 1'b1) ? 3'd0 : (s_stall == 1'b0) ? loadMode : s_loadModeReg;
      s_cacheErrorReg <= (cpuReset == 1'b1 || s_stall == 1'b0) ? 1'b0 : (s_busActionDone == 1'b1) ? s_busErrorReg : s_cacheErrorReg;
    end

  /*
   *
   * Here the pipe-line signals are defined
   *
   */
  reg [31:0] s_memoryAddressReg;
  reg [3:0] s_byteEnablesReg;
  wire [1:0] s_select = loadMode[1:0] | storeMode;
  
  always @(posedge cpuClock)
    begin
      s_memoryAddressReg <= (s_stall == 1'b0) ? memoryAddress : s_memoryAddressReg;
      if (s_stall == 1'b0)
        case (s_select)
          2'b01   : case (memoryAddress[1:0])
                      2'b00   : s_byteEnablesReg <= 4'd1;
                      2'b01   : s_byteEnablesReg <= 4'd2;
                      2'b10   : s_byteEnablesReg <= 4'd4;
                      default : s_byteEnablesReg <= 4'd8;
                    endcase
          2'b10   : s_byteEnablesReg <= (memoryAddress[1] == 1'b0) ? 4'b0011 : 4'b1100;
          default : s_byteEnablesReg <= 4'd15;
        endcase
    end
  
  /*
   *
   * Here the spm is defined
   *
   */
  reg [10:0]   s_spmAddressReg;
  reg [31:0]  s_dataFromCpu, s_dataFromCpuReg;
  wire [3:0]  s_weSpm;
  wire [10:0]  s_spmAddress = (s_stall == 1'b0) ? memoryAddress[12:2] : s_spmAddressReg;
  wire [31:0] s_dataToCpu;
  
  always @(posedge cpuClock) 
    begin
      s_spmAddressReg  <= s_spmAddress;
      s_dataFromCpuReg <= (s_stall == 1'b0) ? s_dataFromCpu : s_dataFromCpuReg;
    end
  
  always @*
    case (storeMode)
      2'b01   : s_dataFromCpu <= cpuDataIn;
      2'b10   : s_dataFromCpu <= {cpuDataIn[23:16], cpuDataIn[31:24], cpuDataIn[7:0], cpuDataIn[15:8]};
      default : s_dataFromCpu <= {cpuDataIn[7:0], cpuDataIn[15:8], cpuDataIn[23:16], cpuDataIn[31:24]};
    endcase

  assign s_weSpm[0] = (memoryAddress[31:13] == SPM_BASE[31:13] && s_stall == 1'b0 &&
                       ((storeMode == 2'b01 && memoryAddress[1:0] == 2'b00) ||
                        (storeMode == 2'b10 && memoryAddress[1] == 1'b0) || storeMode == 2'b11)) ? 1'b1 : 1'b0;
  assign s_weSpm[1] = (memoryAddress[31:13] == SPM_BASE[31:13] && s_stall == 1'b0 &&
                       ((storeMode == 2'b01 && memoryAddress[1:0] == 2'b01) ||
                        (storeMode == 2'b10 && memoryAddress[1] == 1'b0) || storeMode == 2'b11)) ? 1'b1 : 1'b0;
  assign s_weSpm[2] = (memoryAddress[31:13] == SPM_BASE[31:13] && s_stall == 1'b0 &&
                       ((storeMode == 2'b01 && memoryAddress[1:0] == 2'b10) ||
                        (storeMode == 2'b10 && memoryAddress[1] == 1'b1) || storeMode == 2'b11)) ? 1'b1 : 1'b0;
  assign s_weSpm[3] = (memoryAddress[31:13] == SPM_BASE[31:13] && s_stall == 1'b0 &&
                       ((storeMode == 2'b01 && memoryAddress[1:0] == 2'b11) ||
                        (storeMode == 2'b10 && memoryAddress[1] == 1'b1) || storeMode == 2'b11)) ? 1'b1 : 1'b0;
  
  dCacheSpm spm ( .clock(cpuClock),
                  .byteWe(s_weSpm),
                  .address(s_spmAddress),
                  .dataIn(s_dataFromCpu),
                  .dataOut(s_dataToCpu) );
  /*
   *
   * Here the data to the cpu is defined
   *
   */
  wire [31:0] s_selectedData = (s_memoryAddressReg[31:13] == SPM_BASE[31:13]) ? s_dataToCpu : s_fetchedDataReg;
  
  always @*
    case (s_loadModeReg[1:0])
      2'b01   : case (s_memoryAddressReg[1:0])
                  2'b00   : cpuDataOut <= {{24{(s_selectedData[7]&s_loadModeReg[2])}}, s_selectedData[7:0]};
                  2'b01   : cpuDataOut <= {{24{(s_selectedData[15]&s_loadModeReg[2])}}, s_selectedData[15:8]};
                  2'b10   : cpuDataOut <= {{24{(s_selectedData[23]&s_loadModeReg[2])}}, s_selectedData[23:16]};
                  default : cpuDataOut <= {{24{(s_selectedData[31]&s_loadModeReg[2])}}, s_selectedData[31:24]};
                endcase
      2'b10   : cpuDataOut <= (s_memoryAddressReg[1] == 1'b0) ? {{16{(s_selectedData[7]&s_loadModeReg[2])}}, s_selectedData[7:0], s_selectedData[15:8]} :
                              {{16{(s_selectedData[23]&s_loadModeReg[2])}}, s_selectedData[23:16], s_selectedData[31:24]};
      default : cpuDataOut <= {s_selectedData[7:0], s_selectedData[15:8], s_selectedData[23:16], s_selectedData[31:24]};
    endcase

  /*
   *
   * Here the main statemachine is defined
   *
   */
  reg [1:0] s_stateNext;
  
  always @*
    case (s_stateReg)
      IDLE            : s_stateNext <= (s_stallReg == 1'b1) ? REQUEST_ACTION : IDLE;
      REQUEST_ACTION  : s_stateNext <= WAIT_FOR_ACTION;
      WAIT_FOR_ACTION : s_stateNext <= (s_busActionDone == 1'b1) ? SIGNAL_DONE : WAIT_FOR_ACTION;
      default         : s_stateNext <= IDLE;
    endcase
  
  always @(posedge cpuClock) s_stateReg <= (cpuReset == 1'b1) ? IDLE : s_stateNext;

  /*
   *
   * Here all the bus related signals are defined
   *
   */
  reg[2:0] s_busStateNext;
  
  assign requestTheBus       = (s_busStateReg == REQUEST_BUS) ? 1'b1 : 1'b0;
  assign beginTransactionOut = (s_busStateReg == INIT_TRANSACTION) ? 1'b1 : 1'b0;
  assign endTransactionOut   = (s_busStateReg == BUS_ERROR || s_busStateReg == END_WRITE) ? 1'b1 : 1'b0;
  assign byteEnablesOut      = (s_busStateReg == INIT_TRANSACTION) ? s_byteEnablesReg : 4'd0;
  assign burstSizeOut        = 8'd0;
  assign readNotWriteOut     = (s_busStateReg == INIT_TRANSACTION && s_loadModeReg != 3'd0) ? 1'b1 : 1'b0;
  assign addressDataOut      = (s_busStateReg == INIT_TRANSACTION) ? s_memoryAddressReg :
                               (s_busStateReg == DO_WRITE) ? s_dataFromCpuReg : 32'd0;
  assign dataValidOut        = (s_busStateReg == DO_WRITE) ? 1'b1 : 1'b0;
  
  always @*
    case (s_busStateReg)
      NOOP             : s_busStateNext <= (s_stateReg == REQUEST_ACTION) ? REQUEST_BUS : NOOP;
      REQUEST_BUS      : s_busStateNext <= (busAccessGranted == 1'b1) ? INIT_TRANSACTION : REQUEST_BUS;
      INIT_TRANSACTION : s_busStateNext <= (s_loadModeReg == 3'd0) ? DO_WRITE : WAIT_READ;
      WAIT_READ        : s_busStateNext <= (busErrorIn == 1'b1) ? BUS_ERROR :
                                           (endTransactionIn == 1'b1) ? SIG_DONE : WAIT_READ;
      DO_WRITE         : s_busStateNext <= (busErrorIn == 1'b1) ? BUS_ERROR :
                                           (busyIn == 1'b1) ? DO_WRITE : END_WRITE;
      END_WRITE,
      BUS_ERROR        : s_busStateNext <= SIG_DONE;
      default          : s_busStateNext <= IDLE;
    endcase

  always @(posedge cpuClock)
    begin
      s_busStateReg    <= (cpuReset == 1'b1) ? NOOP : s_busStateNext;
      s_busErrorReg    <= (s_busStateReg == REQUEST_BUS) ? 1'b0 : (s_busStateReg == BUS_ERROR) ? 1'b1 : s_busErrorReg;
      s_fetchedDataReg <= (s_busStateReg == WAIT_READ && dataValidIn == 1'b1) ? addressDataIn : s_fetchedDataReg;
    end
endmodule
