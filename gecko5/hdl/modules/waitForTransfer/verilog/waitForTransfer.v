module waitForTransfer #(
    parameter [7:0] CUSTOM_INSTRUCTION_ID = 8'd0
) (
    input wire clock,
    input wire reset,
    input wire dataReady,
    input wire [31:0] numberOfFeatures,
    input wire ciStart,
    input wire ciCke,
    input wire [7:0] ciN,
    input wire [31:0] ciValueA,
    input wire [31:0] ciValueB,
    output reg ciDone,
    output reg [31:0] ciResult
);

  /*
   * This module implements a blocking delay element.
   * It waits for feature transfer to complete and returns number of features transfered.
   *
   */

  wire isMyCi = (ciN == CUSTOM_INSTRUCTION_ID) ? ciStart & ciCke : 1'b0;

  localparam STATE_IDLE = 0;
  localparam STATE_WAIT = 1;
  localparam STATE_DONE = 2;

  localparam NUMBER_OF_STATES = 3;

  reg [$clog2(NUMBER_OF_STATES)-1:0] fsmState;
  reg [$clog2(NUMBER_OF_STATES)-1:0] fsmStateNext = STATE_IDLE;

  always @(posedge clock) begin
    if (reset) begin
      fsmState <= STATE_IDLE;
    end else begin
      fsmState <= fsmStateNext;
    end
  end

  // NSL
  always @(*) begin
    case (fsmState)
      STATE_IDLE: fsmStateNext <= (isMyCi == 'b1) ? STATE_WAIT : STATE_IDLE;
      STATE_WAIT: fsmStateNext <= (dataReady == 'b1) ? STATE_DONE : STATE_WAIT;
      STATE_DONE: fsmStateNext <= STATE_IDLE;
      default: fsmStateNext <= STATE_IDLE;
    endcase
  end

  reg dataReadyReg;
  reg [31:0] numberOfFeaturesReg;

  always @(posedge clock) begin
    dataReadyReg <= dataReady;
    numberOfFeaturesReg <= numberOfFeatures;
    ciDone <= (fsmState == STATE_DONE) ? 'd1 : 'd0;
    ciResult <= (fsmState == STATE_DONE) ? numberOfFeaturesReg : 'd0;
  end

endmodule
