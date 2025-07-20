module strobeControl #(
    parameter [7:0] CUSTOM_INSTRUCTION_ID = 8'd0
) (
    input wire reset,
    input wire pixelClock,
    input wire trigger,
    input wire strobe,
    // custom instruction interface
    input wire systemClock,
    input wire ciStart,
    input wire ciCke,
    input wire [7:0] ciN,
    input wire [31:0] ciValueA,
    input wire [31:0] ciValueB,
    output wire [31:0] ciResult,
    output wire ciDone
);

  /*
   * CUSTOM INSTRUCTION
   *
   * different ci commands:
   * ciValueA:    Description:
   *     0        Enable/Disable strobe output (ciValueB[0])
   *     1        Set delay for value (ciValueB[15:0])
   *     2        Set hold for value (ciValueB[15:0])
   *     3        Get delay for value
   *     4        Get hold for value
   */

  localparam CI_A_ENABLE_STROBE = 0;
  localparam CI_A_SET_DELAY_FOR = 1;
  localparam CI_A_SET_HOLD_FOR = 2;
  localparam CI_A_GET_DELAY_FOR = 3;
  localparam CI_A_GET_HOLD_FOR = 4;
  localparam CI_A_ENABLE_CONSTANT = 5;
  localparam NUMBER_OF_CIS = 6;

  wire isMyCi = (ciN == CUSTOM_INSTRUCTION_ID) ? ciStart & ciCke : 0;

  localparam COUNTERS_NBITS = 32;
  localparam COUNTERS_MAX_CONFIG_VALUE = (2**NBITS)-1;

  reg enableStrobe;
  reg applyConfigSysclk;
  reg [COUNTERS_NBITS-1:0] configDelayFor;
  reg [COUNTERS_NBITS-1:0] configHoldFor;
  reg enableConstant;

  always @(posedge systemClock) begin
    if (reset) begin
      enableStrobe = 1'b0;
      configDelayFor = {COUNTERS_NBITS{1'b0}};
      configHoldFor = {COUNTERS_NBITS{1'b0}};
      applyConfigSysclk = 1'b0;
      enableConstant = 1'b0;
    end else begin
      enableStrobe <= (isMyCi == 1'b1 && (ciValueA[NUMBER_OF_CIS-1:0] == CI_A_ENABLE_STROBE)) ? ciValueB[0] : enableStrobe;
      configDelayFor <= (isMyCi == 1'b1 && (ciValueA[NUMBER_OF_CIS-1:0] == CI_A_SET_DELAY_FOR)) ? ciValueB[COUNTERS_NBITS-1:0] : configDelayFor;
      configHoldFor <= (isMyCi == 1'b1 && (ciValueA[NUMBER_OF_CIS-1:0] == CI_A_SET_HOLD_FOR)) ? ciValueB[COUNTERS_NBITS-1:0] : configHoldFor;
      applyConfigSysclk <= (isMyCi == 1'b1 && (ciValueA[NUMBER_OF_CIS-1:0] == CI_A_SET_DELAY_FOR)) ? 1'b1 :
                           (isMyCi == 1'b1 && (ciValueA[NUMBER_OF_CIS-1:0] == CI_A_SET_HOLD_FOR)) ? 1'b1 : 1'b0;
      enableConstant <= (isMyCi == 1'b1 && (ciValueA[NUMBER_OF_CIS-1:0] == CI_A_ENABLE_CONSTANT)) ? ciValueB[0] : enableConstant;
    end
  end

  reg [31:0] selectedResult = 32'b0; // intentionally set to 0 since process does not define a reset value

  assign ciDone   = isMyCi;
  assign ciResult = (isMyCi == 1'b0) ? 32'd0 : selectedResult;

  always @(*) begin
    case (ciValueA[NUMBER_OF_CIS-1:0])
      CI_A_GET_DELAY_FOR: selectedResult <= {{32-COUNTERS_NBITS{1'b0}}, configDelayFor};
      CI_A_GET_HOLD_FOR: selectedResult <=  {{32-COUNTERS_NBITS{1'b0}}, configHoldFor};
      default: selectedResult <= 32'd0;
    endcase
  end

  wire applyConfigPclk;
  // crossing from sysclk to pclk clock domain
  synchroFlop applyConfig (
      .clockIn(systemClock),
      .clockOut(pixelClock),
      .reset(reset),
      .D(applyConfigSysclk),
      .Q(applyConfigPclk)
  );

  wire strobeDelayedAndHeld;
  hold #(
    .NBITS(COUNTERS_NBITS)
  ) holdStrobe (
    .clk(pixelClock),
    .reset(reset),
    .s(trigger),
    .configDelayFor(configDelayFor),
    .configHoldFor(configHoldFor),// broken! works fine if configDelayFor is passed instead
    .applyConfig(applyConfigPclk),
    .h(strobeDelayedAndHeld)
  );

assign strobe = (enableConstant == 1'b1) ? 'b1 : (enableStrobe == 1'b1) ? strobeDelayedAndHeld : 1'b0;

endmodule
