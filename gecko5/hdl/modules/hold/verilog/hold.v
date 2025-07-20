module hold #(parameter NBITS = 4)
(
  input wire clk,
  input wire reset,
  input wire s,
  input wire [NBITS-1:0] configDelayFor, // delay configDelayFor + 1 clock cycles before h is set
  input wire [NBITS-1:0] configHoldFor, // signal h is held for configHoldFor + 1 clock cycles
  input wire applyConfig,
  output reg h
);

  wire sRising;
  edgeDetect trigger(
    .clk(clk),
    .reset(reset),
    .s(s),
    .pos(sRising)
  );

  wire[NBITS-1:0] delayCountNext;
  reg[NBITS-1:0] delayCount;
  reg[NBITS-1:0] delayCountMax;

  wire[NBITS-1:0] holdCountNext;
  reg[NBITS-1:0] holdCount;
  reg[NBITS-1:0] holdCountMax;

  localparam STATE_IDLE = 0;
  localparam STATE_DELAY = 1;
  localparam STATE_HOLD = 2;
  localparam NUMBER_OF_STATES = 3;
  reg[$clog2(NUMBER_OF_STATES)-1:0] fsmState;
  reg[$clog2(NUMBER_OF_STATES)-1:0] fsmStateNext = STATE_IDLE; //TODO: wire?

  always @(posedge clk) begin
    if (reset) begin
      fsmState <= STATE_IDLE;
      delayCount <= {NBITS{1'b0}};
      holdCount <= {NBITS{1'b0}};
    end else begin
      fsmState <= fsmStateNext;
      delayCount <= delayCountNext;
      holdCount <= holdCountNext;
    end
  end

  reg delayDone;
  reg holdDone;

  // nsl main fsm
  always @(*) begin
    case (fsmState)
      STATE_IDLE: fsmStateNext <= (applyConfig == 'b1) ? STATE_IDLE :
                                  (sRising == 'b1) ? STATE_DELAY : STATE_IDLE ;
      STATE_DELAY: fsmStateNext <= (applyConfig == 'b1) ? STATE_IDLE :
                                   (delayDone == 'b1) ? STATE_HOLD : STATE_DELAY;
      STATE_HOLD: fsmStateNext <= (applyConfig == 'b1) ? STATE_IDLE :
                                  (holdDone == 'b1) ? STATE_IDLE : STATE_HOLD;
      default: fsmStateNext <= STATE_IDLE;
    endcase
  end
  // nsl counters
  assign delayCountNext = (fsmState == STATE_DELAY) ? delayCount + 'd1 : {NBITS{1'b0}};
  assign holdCountNext = (fsmState == STATE_HOLD) ? holdCount + 'd1 : {NBITS{1'b0}};

  // ol main fsm
  always @(posedge clk) begin
    h <= (fsmState == STATE_HOLD) ? 1'b1 : 1'b0;
    delayDone <= (delayCount == delayCountMax) ? 1'b1 : 1'b0;
    holdDone <= (holdCount == holdCountMax) ? 1'b1 : 1'b0;
    delayCountMax <= (reset == 1'b1) ? {NBITS{1'b0}} :
                     (applyConfig == 1'b1) ? configDelayFor :
                     delayCountMax;
    holdCountMax <= (reset == 1'b1) ? {NBITS{1'b0}} :
                    (applyConfig == 1'b1) ? configHoldFor :
                    holdCountMax;
  end

endmodule