module cameraSelector #(
    parameter [7:0] CUSTOM_INSTRUCTION_ID = 8'd0
) (
    input wire reset,
    input wire pixelClock,
    // input feeds
    input wire hrefReal,
    input wire vsyncReal,
    input wire [7:0] camDataReal,

    input wire hrefFakeStatic,
    input wire vsyncFakeStatic,
    input wire [7:0] camDataFakeStatic,

    input wire hrefFakeMoving,
    input wire vsyncFakeMoving,
    input wire [7:0] camDataFakeMoving,

    input wire hrefBin,
    input wire vsyncBin,
    input wire [7:0] camDataBin,

    // output feeds
    output reg hrefPipeline,
    output reg vsyncPipeline,
    output reg [7:0] camDataPipeline,

    output reg hrefScreen,
    output reg vsyncScreen,
    output reg [7:0] camDataScreen,

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
   *     0        Set output mode (viValueB[0]). Mode0: greyscale, Mode1: binary
   *     1        Set input mode (viValueB[1:0]). Mode0: real, Mode1: fake static, Mode2: fake moving
   */


  localparam CI_A_OUTPUT_MODE = 0;
  localparam CI_A_INPUT_MODE = 1;

  localparam CI_B_OUTPUT_MODE_RGB = 0;
  localparam CI_B_OUTPUT_MODE_BIN = 1;

  localparam CI_B_INPUT_MODE_REAL = 0;
  localparam CI_B_INPUT_MODE_FAKE_STATIC = 1;
  localparam CI_B_INPUT_MODE_FAKE_MOVING = 2;

  wire isMyCi = (ciN == CUSTOM_INSTRUCTION_ID) ? ciStart & ciCke : 0;

  reg outputMode;
  reg [1:0] inputMode;

  always @(posedge systemClock) begin
    if (reset) begin
      outputMode <= CI_B_OUTPUT_MODE_RGB;
      inputMode  <= CI_B_INPUT_MODE_REAL;
    end else begin
      outputMode <= (isMyCi == 1'b1 && (ciValueA[0] == CI_A_OUTPUT_MODE)) ? ciValueB[0] : outputMode;
      inputMode <= (isMyCi == 1'b1 && (ciValueA[0] == CI_A_INPUT_MODE)) ? ciValueB[1:0] : inputMode;
    end
  end

  reg [31:0] selectedResult = 0; // intentionally set to 0 since process does not define a reset value

  assign ciDone   = isMyCi;
  assign ciResult = (isMyCi == 1'b0) ? 32'd0 : selectedResult;

  always @(*) begin
    case (ciValueA[0])
      default: selectedResult <= 32'd0;
    endcase
  end

  wire hrefRgb, vsyncRgb;
  wire [7:0] camDataRgb;
  assign hrefRgb = (inputMode == CI_B_INPUT_MODE_FAKE_STATIC) ? hrefFakeStatic :
                   (inputMode == CI_B_INPUT_MODE_FAKE_MOVING) ? hrefFakeMoving :
                   hrefReal;
  assign vsyncRgb = (inputMode == CI_B_INPUT_MODE_FAKE_STATIC) ? vsyncFakeStatic :
                    (inputMode == CI_B_INPUT_MODE_FAKE_MOVING) ? vsyncFakeMoving :
                    vsyncReal;
  assign camDataRgb = (inputMode == CI_B_INPUT_MODE_FAKE_STATIC) ? camDataFakeStatic :
                      (inputMode == CI_B_INPUT_MODE_FAKE_MOVING) ? camDataFakeMoving :
                      camDataReal;
  // clocked output
  always @(posedge pixelClock) begin
    hrefPipeline <= hrefRgb;
    vsyncPipeline <= vsyncRgb;
    camDataPipeline <= camDataRgb;

    hrefScreen <= (outputMode == CI_B_OUTPUT_MODE_BIN) ? hrefBin : hrefRgb;
    vsyncScreen <= (outputMode == CI_B_OUTPUT_MODE_BIN) ? vsyncBin : vsyncRgb;
    camDataScreen <= (outputMode == CI_B_OUTPUT_MODE_BIN) ? camDataBin : camDataRgb;
  end
endmodule
