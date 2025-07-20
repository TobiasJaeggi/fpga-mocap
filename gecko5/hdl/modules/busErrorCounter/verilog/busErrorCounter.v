module busErrorCounter #(
    parameter [7:0] CUSTOM_INSTRUCTION_ID = 8'd0
) (
    input wire reset,
    input wire systemClock,
    input wire busErrorIn,
    // custom instruction interface
    input wire ciStart,
    input wire ciCke,
    input wire [7:0] ciN,
    input wire [31:0] ciValueA,
    input wire [31:0] ciValueB,
    output wire [31:0] ciResult,
    output wire ciDone
);

  wire errorPulse;
  edgeDetect errorEdge (
      .clk(systemClock),
      .reset(reset),
      .s(busErrorIn),
      .pos(errorPulse),
      .neg()
  );

  /*
   * CUSTOM INSTRUCTION
   *
   * different ci commands:
   * ciValueA:    Description:
   *     0        Read bus error counter
   *     1        Reset bus error counter
   *
   */

  localparam CI_A_READ = 0;
  localparam CI_A_RESET = 1;

  wire isMyCi = (ciN == CUSTOM_INSTRUCTION_ID) ? ciStart & ciCke : 0;
  reg [31:0] busErrorCounter;

  always @(posedge systemClock) begin
    if (reset) begin
      busErrorCounter <= 0;
    end else begin
      busErrorCounter <= (isMyCi == 1'b1 && (ciValueA[0] == CI_A_RESET)) ? 'd0 : (errorPulse == 1) ? busErrorCounter + 1 : busErrorCounter;
    end
  end

  reg [31:0] selectedResult = 0; // intentionally set to 0 since process does not define a reset value

  assign ciDone   = isMyCi;
  assign ciResult = (isMyCi == 1'b0) ? 32'd0 : selectedResult;

  always @(*) begin
    case (ciValueA[0])
      CI_A_READ: selectedResult <= busErrorCounter;
      default: selectedResult <= 32'd0;
    endcase
  end

endmodule
