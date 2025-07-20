module binarize #(
    parameter [7:0] CUSTOM_INSTRUCTION_ID = 'd0
) (
    input wire pclk,
    input wire reset,
    input wire href,
    input wire vsync,  // low active!
    input wire [7:0] camData,

    output reg hrefBin,
    output reg vsyncBin,  // low active!
    output reg [7:0] camDataBin,

    input wire systemClock,
    // ci  
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
   *     0        Read threshold value (ciResult[7:0])
   *     1        Write threshold value (ciValueB[7:0])
   *
   */
  localparam CI_A_READ_THRESHOLD = 0;
  localparam CI_A_WRITE_THRESHOLD = 1;

  localparam DEFAULT_THRESHOLD = 10;

  wire isMyCi = (ciN == CUSTOM_INSTRUCTION_ID) ? ciStart & ciCke : 'b0;
  reg [7:0] threshold;

  always @(posedge systemClock) begin
    if (reset) begin
      threshold <= DEFAULT_THRESHOLD;
    end else begin
      threshold <= (isMyCi == 'b1 && (ciValueA[0] == CI_A_WRITE_THRESHOLD)) ? ciValueB[7:0] : threshold;
    end
  end

  reg [31:0] selectedResult = 'd0; // intentionally set to 0 since process does not define a reset value

  assign ciDone   = isMyCi;
  assign ciResult = (isMyCi == 'b0) ? 'd0 : selectedResult;

  always @(*) begin
    case (ciValueA)
      CI_A_READ_THRESHOLD: selectedResult <= {24'b0, threshold};
      default: selectedResult <= 'd0;
    endcase
  end

  wire [7:0] binarized = (camData >= threshold) ? 'hFF : 'h00;

  always @(posedge pclk) begin
      hrefBin <= href;
      vsyncBin <= vsync;
      camDataBin <= binarized;
  end


endmodule
