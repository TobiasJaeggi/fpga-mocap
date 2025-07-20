module busArbiter ( input wire         clock,
                                       reset,
                    input wire [31:0]  busRequests,
                    output reg [31:0]  busGrants,
                    output reg         busErrorOut,
                                       endTransactionOut,
                                       busIdle,
                                       snoopableBurst,
                    input wire         beginTransactionIn,
                                       endTransactionIn,
                                       dataValidIn,
                    input wire [31:30] addressDataIn,
                    input wire [7:0]   burstSizeIn );
  
  localparam [2:0] IDLE            = 3'b000;
  localparam [2:0] GRANT           = 3'b001;
  localparam [2:0] WAIT_BEGIN      = 3'b010;
  localparam [2:0] SERVICING       = 3'b011;
  localparam [2:0] INIT_BUS_ERROR  = 3'b111;
  localparam [2:0] BUS_ERROR       = 3'b100;
  localparam [2:0] END_TRANSACTION = 3'b101;
  localparam [2:0] REMOVE          = 3'b110;
  
  // here we define the state machine
  reg  [4:0]  s_queueRemovePointerReg,s_queueInsertPointerReg;
  reg  [2:0]  s_stateReg, s_stateNext;
  reg         s_activeTransactionReg;
  reg [15:0]  s_timeOutReg;
  reg [31:0] s_queuedRequests, s_toBeQueuedMask;
  wire [31:0] s_grantMask;
  wire [4:0]  s_queueRemovePointerNext = (s_stateReg == REMOVE) ? s_queueRemovePointerReg + 5'd1 : s_queueRemovePointerReg;
  wire        s_queueEmpty = (s_queuedRequests == 32'd0) ? 1'b1 : 1'b0;
  wire        s_activeTransactionNext = (s_stateReg == WAIT_BEGIN && beginTransactionIn == 1'b1) ? 1'b1 :
                                        ((s_stateReg == SERVICING && endTransactionIn == 1'b1) || s_stateReg == IDLE) ? 1'b0 : s_activeTransactionReg;
  wire [15:0] s_timeOutNext = (reset == 1'b1 || s_stateReg == GRANT || s_stateReg == INIT_BUS_ERROR || (beginTransactionIn == 1'b1 && s_stateReg == WAIT_BEGIN) || 
                               (dataValidIn == 1'b1 && s_stateReg == SERVICING)) ? 16'hFFFF :
                              (s_timeOutReg[15] == 1'b1) ? s_timeOutReg - 16'd1 : s_timeOutReg;
  
  always @*
    case (s_stateReg)
      IDLE                : s_stateNext <= (beginTransactionIn == 1'b1) ? INIT_BUS_ERROR : (s_queueEmpty == 1'b0) ? GRANT : IDLE;
      GRANT               : s_stateNext <= (beginTransactionIn == 1'b1) ? INIT_BUS_ERROR : WAIT_BEGIN;
      WAIT_BEGIN          : s_stateNext <= (beginTransactionIn == 1'b1) ? SERVICING : (s_timeOutReg[15] == 1'b0) ? REMOVE : WAIT_BEGIN;
      SERVICING           : s_stateNext <= (beginTransactionIn == 1'b1 || s_timeOutReg[15] == 1'b0) ? INIT_BUS_ERROR : (endTransactionIn == 1'b1) ? REMOVE : SERVICING;
      INIT_BUS_ERROR      : s_stateNext <= (endTransactionIn == 1'b1) ? IDLE : BUS_ERROR;
      BUS_ERROR           : s_stateNext <= (s_timeOutReg[15] == 1'b0) ? END_TRANSACTION : (endTransactionIn == 1'b1 && s_activeTransactionReg == 1'b1) ? REMOVE :
                                           (endTransactionIn == 1'b1) ? IDLE : BUS_ERROR;
      default             : s_stateNext <= IDLE;
    endcase
  
  always @(posedge clock)
    begin
      s_stateReg              <= (reset == 1'b1) ? IDLE : s_stateNext;
      s_queueRemovePointerReg <= (reset == 1'b1) ? 5'd0 : s_queueRemovePointerNext;
      busGrants               <= (reset == 1'b1) ? 32'd0 : (s_stateReg == GRANT && beginTransactionIn == 1'b0) ? s_grantMask : 32'd0;
      s_timeOutReg            <= s_timeOutNext;
      s_activeTransactionReg  <= (reset == 1'b1) ? 1'b0 : s_activeTransactionNext;
      busErrorOut             <= (reset == 1'b1 || endTransactionIn == 1'b1) ? 1'b0 : (s_stateReg == INIT_BUS_ERROR || s_stateReg == BUS_ERROR) ? 1'b1 : 1'b0;
      endTransactionOut       <= (reset == 1'b1) ? 1'b0 : (s_stateReg == END_TRANSACTION) ? 1'b1 : 1'b0;
      busIdle                 <= (reset == 1'b1) ? 1'b1 : ~s_activeTransactionReg;
      snoopableBurst          <= (reset == 1'b1) ? 1'b0 : (beginTransactionIn == 1'b1 && addressDataIn == 2'd0 && burstSizeIn == 8'd7) ? 1'b1 : 1'b0;
    end
  

  // here we define the queue
  reg [2:0] s_groupSelect;
  wire [7:0] s_orMasks;
  wire [31:0] s_selectMask;
  
  wire [31:0] s_outstandingRequests = busRequests & ~s_queuedRequests;
  wire        s_insertIntoQueue = (s_outstandingRequests == 32'd0) ? 1'b0 : 1'b1;
  wire [31:0] s_queueRequestsNext = (s_insertIntoQueue == 1'b1 && s_stateReg != REMOVE) ? s_queuedRequests | s_toBeQueuedMask :
                                    (s_insertIntoQueue == 1'b1 && s_stateReg == REMOVE) ? (s_queuedRequests | s_toBeQueuedMask) & ~s_grantMask : 
                                    (s_stateReg == REMOVE) ? s_queuedRequests & ~s_grantMask : s_queuedRequests;
  wire [4:0]  s_queueInsertPointerNext = (s_insertIntoQueue == 1'b1) ? s_queueInsertPointerReg + 5'd1 : s_queueInsertPointerReg;
  wire [1:0]  s_select;
  assign s_select[1] = s_orMasks[4] | s_orMasks[5] | s_orMasks[6] | s_orMasks[7]; 
  assign s_select[0] = (s_select[1] == 1'b1) ? s_orMasks[6] | s_orMasks[7] : s_orMasks[2] | s_orMasks[3];

  genvar n;
  
  always @(posedge clock) 
    begin
      s_queuedRequests        <= (reset == 1'b1) ? 32'd0 : s_queueRequestsNext;
      s_queueInsertPointerReg <= (reset == 1'b1) ? 5'd0 : s_queueInsertPointerNext;
    end
  
  /* here we define the priority encoding, note that request 31 has the highes priority */
  always @*
    case (s_select)
      2'd0    : s_groupSelect <= {s_select,s_orMasks[1]};
      2'd1    : s_groupSelect <= {s_select,s_orMasks[3]};
      2'd2    : s_groupSelect <= {s_select,s_orMasks[5]};
      default : s_groupSelect <= {s_select,s_orMasks[7]};
    endcase
  
  generate
    for (n = 0 ; n < 8 ; n = n + 1)
      begin:genit
        assign s_orMasks[n]        = s_outstandingRequests[n*4] | s_outstandingRequests[n*4+1] | s_outstandingRequests[n*4+2] | s_outstandingRequests[n*4+3];
        assign s_selectMask[n*4]   = s_outstandingRequests[n*4] & ~s_outstandingRequests[n*4+3] & ~s_outstandingRequests[n*4+2] & ~s_outstandingRequests[n*4+1];
        assign s_selectMask[n*4+1] = s_outstandingRequests[n*4+1] & ~s_outstandingRequests[n*4+3] & ~s_outstandingRequests[n*4+2];
        assign s_selectMask[n*4+2] = s_outstandingRequests[n*4+2] & ~s_outstandingRequests[n*4+3];
        assign s_selectMask[n*4+3] = s_outstandingRequests[n*4+3];
      end
  endgenerate
  
  always @*
    case (s_groupSelect)
      3'd0    : s_toBeQueuedMask <= {28'd0,s_selectMask[3:0]};
      3'd1    : s_toBeQueuedMask <= {24'd0,s_selectMask[7:4],4'd0};
      3'd2    : s_toBeQueuedMask <= {20'd0,s_selectMask[11:8],8'd0};
      3'd3    : s_toBeQueuedMask <= {16'd0,s_selectMask[15:12],12'd0};
      3'd4    : s_toBeQueuedMask <= {12'd0,s_selectMask[19:16],16'd0};
      3'd5    : s_toBeQueuedMask <= {8'd0,s_selectMask[23:20],20'd0};
      3'd6    : s_toBeQueuedMask <= {4'd0,s_selectMask[27:24],24'd0};
      default : s_toBeQueuedMask <= {s_selectMask[31:28],28'd0};
    endcase

  queueMemory queue ( .writeClock(clock),
                      .writeEnable(s_insertIntoQueue),
                      .writeAddress(s_queueInsertPointerReg),
                      .readAddress(s_queueRemovePointerReg),
                      .writeData(s_toBeQueuedMask),
                      .dataReadPort(s_grantMask) );

endmodule
