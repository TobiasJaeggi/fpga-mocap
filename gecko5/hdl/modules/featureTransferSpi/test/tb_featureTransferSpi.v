module tb_featureTransferSpi;
  localparam integer NUM_BITS_X = 4;
  localparam integer NUM_BITS_Y = 4;
  localparam integer FEATURE_WIDTH = ((NUM_BITS_X + NUM_BITS_Y) * 2);
  reg reset = 0;
  // cam domain
  reg pixClock = 0;
  reg featureValid = 0;
  reg [FEATURE_WIDTH-1:0] featureVecCamDomain = 0;
  reg vSync = 0;
  // sys domain
  reg sysClock = 0;
  // spi
  wire spiSck;
  wire spiMosi;
  wire spiMiso;
  wire spiTransferDone;

  assign spiMiso = spiMosi;
  featureTransferSpi #(
      .NUM_BITS_X(NUM_BITS_X),
      .NUM_BITS_Y(NUM_BITS_Y)
  ) ft (
      .reset(reset),
      .pixelClock(pixClock),
      .featureValid(featureValid),
      .featureVector(featureVecCamDomain),
      .cameraVsync(vSync),
      .systemClock(sysClock),
      // spi
      .spiSck(spiSck),
      .spiMosi(spiMosi),
      .spiMiso(spiMiso),
      .spiTransferDone(spiTransferDone)
  );

  always #1 sysClock = ~sysClock;

  always #4 pixClock = ~pixClock;

  task writeFeature;
    begin
      @(posedge pixClock) #0 featureValid = 1;
      @(posedge pixClock) #0 featureValid = 0;
    end
  endtask

  task sync;
    begin
      @(posedge pixClock) #0 vSync = 0;
      @(posedge pixClock) #0 vSync = 1;
    end
  endtask

  task waitForTransfer;
    begin
      @(posedge spiTransferDone);
    end
  endtask

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_featureTransferSpi);
    reset = 1;
    pixClock = 0;
    featureValid = 0;
    featureVecCamDomain = 0;
    vSync = 1;
    sysClock = 0;
    #10 reset = 0;

    // write no features
    #10 sync();

    #10 featureVecCamDomain = 'h134A;
    writeFeature();
    waitForTransfer();
    #10 sync();

    #80 featureVecCamDomain = 'h2468;
    writeFeature();
    #10 featureVecCamDomain = 'hAF38;
    writeFeature();
    waitForTransfer();
    #10 sync();

    #80 featureVecCamDomain = 'h0156;
    writeFeature();
    #10 featureVecCamDomain = 'hAC5E;
    writeFeature();
    #10 featureVecCamDomain = 'h8F6F;
    writeFeature();
    waitForTransfer();
    #10 sync();

    #80 featureVecCamDomain = 'h4321;
    writeFeature();
    #10 featureVecCamDomain = 'h8765;
    writeFeature();
    #10 featureVecCamDomain = 'hCBA9;
    writeFeature();
    #10 featureVecCamDomain = 'h0FED;
    writeFeature();
    waitForTransfer();
    #10 sync();

    // write no features
    waitForTransfer();
    #200 // To allow spi rx

    $finish;
    //TODO spam sync, sync during tx, reset
    /*
    #180 reset = 1;
    #10 reset = 0;
    featureVecCamDomain = 'h1718;
    writeFeature();
    #10 featureVecCamDomain = 'h6829;
    writeFeature();
    #10 featureVecCamDomain = 'hAF36;
    writeFeature();
    waitForTransfer();
    #10 sync();

    #10 sync();

    #10 sync();

    #10 featureVecCamDomain = 'h1234;
    writeFeature();
    #10 featureVecCamDomain = 'h5678;
    writeFeature();
    #10 featureVecCamDomain = 'h9ABC;
    writeFeature();
    #10 featureVecCamDomain = 'hDEF0;
    writeFeature();
    waitForTransfer();
    #10 sync();

    #80 featureVecCamDomain = 'h1111;
    writeFeature();
    #10 featureVecCamDomain = 'h2222;
    writeFeature();
    #10 featureVecCamDomain = 'h3333;
    writeFeature();
    #10 featureVecCamDomain = 'h4444;
    writeFeature();
    waitForTransfer();
    #10 sync();

    #160 $finish;
    */
  end

endmodule
