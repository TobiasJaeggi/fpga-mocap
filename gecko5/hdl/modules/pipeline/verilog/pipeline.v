module pipeline #(
    parameter [7:0] BINARIZE_CUSTOM_INSTRUCTION_ID = 8'd0,
) (
    input wire reset,
    // camera domain
    input wire pixelClock,
    input wire href,
    input wire vsync,  // low active!
    input wire [7:0] camData,
    // system domain
    input wire systemClock,
    // custom instruction interface
    input wire ciStart,
    input wire ciCke,
    input wire [7:0] ciN,
    input wire [31:0] ciValueA,
    input wire [31:0] ciValueB,
    output wire [31:0] ciResult,
    output wire ciDone,
    // binarized output
    output wire hrefBinOut,
    output wire vsyncBinOut,
    output wire [7:0] camDataBinOut,
    // spi master interface
    output wire spiSck,
    output wire spiMosi,
    input wire spiMiso,
    output wire spiTransferDone,
    // debug
    output wire [15:0] analogDiscovery

);

  wire [31:0] ciResultBinarize;
  wire ciDoneBinarize;

  wire hrefBin, vsyncBin;
  wire [7:0] camDataBin;

  binarize #(
      .CUSTOM_INSTRUCTION_ID(BINARIZE_CUSTOM_INSTRUCTION_ID)
  ) binarizeCamera (
      .pclk(pixelClock),
      .reset(reset),
      .href(href),
      .vsync(vsync),
      .camData(camData),

      .hrefBin(hrefBin),
      .vsyncBin(vsyncBin),
      .camDataBin(camDataBin),
      // ci
      .systemClock(systemClock),
      .ciStart(ciStart),
      .ciCke(ciCke),
      .ciN(ciN),
      .ciValueA(ciValueA),
      .ciValueB(ciValueB),
      .ciResult(ciResultBinarize),
      .ciDone(ciDoneBinarize)
  );
  // binarized video output
  assign hrefBinOut = hrefBin;
  assign vsyncBinOut = vsyncBin;
  assign camDataBinOut = camDataBin;

  localparam IMAGE_WIDTH = 1280;
  localparam NUM_BITS_X = $clog2(IMAGE_WIDTH);
  localparam IMAGE_HEIGHT = 800;
  localparam NUM_BITS_Y = $clog2(IMAGE_HEIGHT);
  localparam FEATURE_WIDTH = (NUM_BITS_X + NUM_BITS_Y) * 2;

  wire featureValidCamDomain;
  wire [FEATURE_WIDTH-1:0] featureVectorCamDomain;
 
  wire vsyncBinEdge;
  edgeDetect vsyncRE (
      .clk(pixelClock),
      .reset(reset),
      .s(vsyncBin),
      .neg(vsyncBinEdge)
  );

  wire binValid;
  assign binValid = hrefBin & vsyncBin;
  LinkRunCCA cca (
      .clk(pixelClock),
      .rst(vsyncBinEdge),
      .datavalid(binValid),
      .pix_in(camDataBin[0]),
      .datavalid_out(featureValidCamDomain),
      .box_out(featureVectorCamDomain)
  );

  wire [31:0] numberOfFeatures;

  featureTransferSpi #(
      .NUM_BITS_X(NUM_BITS_X),
      .NUM_BITS_Y(NUM_BITS_Y)
  ) ft (
      .reset(reset),
      // cam domain
      .pixelClock(pixelClock),
      .featureValid(featureValidCamDomain),
      .featureVector(featureVectorCamDomain),
      .cameraVsync(vsyncBin),  // low active!
      // sys domain
      .systemClock(systemClock),
      // spi
      .spiSck(spiSck),
      .spiMosi(spiMosi),
      .spiMiso(spiMiso),
      .spiTransferDone(spiTransferDone)
  );

  assign ciResult = ciResultBinarize;
  assign ciDone = ciDoneBinarize;

endmodule
