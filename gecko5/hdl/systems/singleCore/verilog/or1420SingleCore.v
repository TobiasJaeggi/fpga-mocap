module or1420SingleCore (
    input wire clock12MHz,
    input wire clock50MHz,
    input wire nReset,

    // USB UART
    input  wire UsbUartRxD,
    output wire UsbUartTxD,

    // SDR SDRAM
    output wire sdramClk,
    output wire sdramCke,
    output wire sdramCsN,
    output wire sdramRasN,
    output wire sdramCasN,
    output wire sdramWeN,
    output wire [1:0] sdramDqmN,
    output wire [12:0] sdramAddr,
    output wire [1:0] sdramBa,
    inout wire [15:0] sdramData,

    // SPI Flash
    output wire spiScl,
    output wire spiNCs,
    inout  wire spiSiIo0,
    inout  wire spiSoIo1,
    inout  wire spiIo2,
    inout  wire spiIo3,

    // HDMI
    output wire pixelClock,
    output wire horizontalSync,
    output wire verticalSync,
    output wire activePixel,
    output wire [4:0] hdmiRed,
    output wire [4:0] hdmiBlue,
    output wire [4:0] hdmiGreen,

    output wire SCL,
    inout  wire SDA,
    input  wire biosBypass,

    // Vision Add-On interface

    // UART command handler
    input  wire visionAddOnUartTxD,
    output wire visionAddOnUartRxD,

    // video in
    input wire camPclk,
    input wire camHref,
    input wire camVsync,
    input wire [7:0] camData,

    // video out
    output wire       visionAddOnCamPclk,
    output wire       visionAddOnCamHref,
    output wire       visionAddOnCamVsync,
    output wire [7:0] visionAddOnCamData,

    // IR flash
    output wire strobe,

    // Feature tranfser
    output wire visionAddOnSpiSck,
    input  wire visionAddOnSpiMiso,
    output wire visionAddOnSpiMosi,
    output wire visionAddOnSpiTransferDone
);

  wire s_busIdle, s_snoopableBurst;
  wire s_hdmiDone, s_systemClock, s_systemClockX2, s_swapByteDone, s_flashDone, s_cpuFreqDone;
  wire [31:0] s_hdmiResult, s_swapByteResult, s_flashResult, s_cpuFreqResult;
  wire [5:0] s_memoryDistance = 6'd0;
  wire s_busError, s_beginTransaction, s_endTransaction;
  wire [31:0] s_addressData;
  wire [ 3:0] s_byteEnables;
  wire s_readNotWrite, s_dataValid, s_busy;
  wire [7:0] s_burstSize;

  /*
   *
   * We use a PLL to generate the required clocks for the HDMI part
   *
   */
  reg  [4:0] s_resetCountReg;
  wire       s_pixelClock;
  wire       s_pixelClkX2;
  wire       s_pllLocked;
  wire       s_reset = ~s_resetCountReg[4];

  always @(posedge s_systemClock or negedge s_pllLocked)
    if (s_pllLocked == 1'b0) s_resetCountReg <= 5'd0;
    else s_resetCountReg <= (s_resetCountReg[4] == 1'b0) ? s_resetCountReg + 5'd1 : s_resetCountReg;

  wire s_resetPll = ~nReset;
  wire s_feedbackClock;
  // CPU @ 74.25MHz
  EHXPLLL #(
      .PLLRST_ENA("ENABLED"),
      .INTFB_WAKE("DISABLED"),
      .STDBY_ENABLE("DISABLED"),
      .DPHASE_SOURCE("DISABLED"),
      .OUTDIVIDER_MUXA("DIVA"),
      .OUTDIVIDER_MUXB("DIVB"),
      .OUTDIVIDER_MUXC("DIVC"),
      .OUTDIVIDER_MUXD("DIVD"),
      .CLKI_DIV(1),
      .CLKOP_ENABLE("ENABLED"),
      .CLKOP_DIV(4),
      .CLKOP_CPHASE(1),
      .CLKOP_FPHASE(0),
      .CLKOS_ENABLE("ENABLED"),
      .CLKOS_DIV(8),
      .CLKOS_CPHASE(1),
      .CLKOS_FPHASE(0),
      .CLKOS2_ENABLE("ENABLED"),
      .CLKOS2_DIV(8),
      .CLKOS2_CPHASE(1),
      .CLKOS2_FPHASE(0),
      .CLKOS3_ENABLE("ENABLED"),
      .CLKOS3_DIV(4),
      .CLKOS3_CPHASE(1),
      .CLKOS3_FPHASE(0),
      .FEEDBK_PATH("INT_OP"),
      .CLKFB_DIV(2)
  ) pll_1 (
      .RST(s_resetPll),
      .STDBY(1'b0),
      .CLKI(clock12MHz),
      .CLKOP(s_pixelClkX2),
      .CLKOS(s_pixelClock),
      .CLKOS2(s_systemClock),
      .CLKOS3(s_systemClockX2),
      .CLKFB(s_feedbackClock),
      .CLKINTFB(s_feedbackClock),
      .PHASESEL0(1'b0),
      .PHASESEL1(1'b0),
      .PHASEDIR(1'b1),
      .PHASESTEP(1'b1),
      .PHASELOADREG(1'b1),
      .PLLWAKESYNC(1'b0),
      .ENCLKOP(1'b0),
      .LOCK(s_pllLocked)
  );

  /*
   * Here we instantiate the UART0
   *
   */
  wire s_uart0Irq, s_uart0EndTransaction, s_uart0DataValid, s_uart0BusError;
  wire [31:0] s_uart0AddressData;
  uartBus #(
      .baseAddress(32'h50000000)
  ) uart0 (
      .clock(s_systemClock),
      .reset(s_reset),
      .irq(s_uart0Irq),
      .beginTransactionIn(s_beginTransaction),
      .endTransactionIn(s_endTransaction),
      .readNWriteIn(s_readNotWrite),
      .dataValidIn(s_dataValid),
      .busyIn(s_busy),
      .addressDataIn(s_addressData),
      .byteEnablesIn(s_byteEnables),
      .burstSizeIn(s_burstSize),
      .addressDataOut(s_uart0AddressData),
      .endTransactionOut(s_uart0EndTransaction),
      .dataValidOut(s_uart0DataValid),
      .busErrorOut(s_uart0BusError),
      .RxD(UsbUartRxD),
      .TxD(UsbUartTxD)
  );

  /*
   * Here we instantiate the UART1
   *
   */
  wire s_uart1Irq, s_uart1EndTransaction, s_uart1DataValid, s_uart1BusError;
  wire [31:0] s_uart1AddressData;
  uartBus #(
      .baseAddress(32'h50000010)
  ) uart1 (
      .clock(s_systemClock),
      .reset(s_reset),
      .irq(s_uart1Irq),
      .beginTransactionIn(s_beginTransaction),
      .endTransactionIn(s_endTransaction),
      .readNWriteIn(s_readNotWrite),
      .dataValidIn(s_dataValid),
      .busyIn(s_busy),
      .addressDataIn(s_addressData),
      .byteEnablesIn(s_byteEnables),
      .burstSizeIn(s_burstSize),
      .addressDataOut(s_uart1AddressData),
      .endTransactionOut(s_uart1EndTransaction),
      .dataValidOut(s_uart1DataValid),
      .busErrorOut(s_uart1BusError),
      .RxD(visionAddOnUartTxD),
      .TxD(visionAddOnUartRxD)
  );

  /*
   * Here we instantiate the SDRAM controller
   *
   */
  wire s_sdramInitBusy, s_sdramEndTransaction, s_sdramDataValid;
  wire s_sdramBusy, s_sdramBusError;
  wire [31:0] s_sdramAddressData;
  wire        s_cpuReset = s_reset | s_sdramInitBusy;

  sdramController #(
      .baseAddress(32'h00000000),
      .systemClockInHz(42857143)
  ) sdram (
      .clock(s_systemClock),
      .clockX2(s_systemClockX2),
      .reset(s_reset),
      .memoryDistanceIn(s_memoryDistance),
      .sdramInitBusy(s_sdramInitBusy),
      .beginTransactionIn(s_beginTransaction),
      .endTransactionIn(s_endTransaction),
      .readNotWriteIn(s_readNotWrite),
      .dataValidIn(s_dataValid),
      .busErrorIn(s_busError),
      .busyIn(s_busy),
      .addressDataIn(s_addressData),
      .byteEnablesIn(s_byteEnables),
      .burstSizeIn(s_burstSize),
      .endTransactionOut(s_sdramEndTransaction),
      .dataValidOut(s_sdramDataValid),
      .busyOut(s_sdramBusy),
      .busErrorOut(s_sdramBusError),
      .addressDataOut(s_sdramAddressData),
      .sdramClk(sdramClk),
      .sdramCke(sdramCke),
      .sdramCsN(sdramCsN),
      .sdramRasN(sdramRasN),
      .sdramCasN(sdramCasN),
      .sdramWeN(sdramWeN),
      .sdramDqmN(sdramDqmN),
      .sdramAddr(sdramAddr),
      .sdramBa(sdramBa),
      .sdramData(sdramData)
  );

  /*
   * Here we instantiate the CPU
   *
   */
  wire [31:0] s_cpu1CiResult, s_i2cCiResult, s_delayResult, s_pipelineCiResult, s_busErrorCounterCiResult, s_cameraSelectorCiResult, s_strobeControlCiResult;
  wire [31:0] s_cpu1CiDataA, s_cpu1CiDataB;
  wire [7:0] s_cpu1CiN;
  wire s_cpu1CiRa, s_cpu1CiRb, s_cpu1CiRc, s_cpu1CiStart, s_cpu1CiCke;
  wire        s_cpu1CiDone, s_i2cCiDone, s_delayCiDone, s_pipelineCiDone, s_busErrorCounterCiDone, s_cameraSelectorCiDone, s_strobeControlCiDone;
  wire [4:0] s_cpu1CiA, s_cpu1CiB, s_cpu1CiC;
  wire s_cpu1IcacheRequestBus, s_cpu1DcacheRequestBus;
  wire s_cpu1IcacheBusAccessGranted, s_cpu1DcacheBusAccessGranted;
  wire s_cpu1BeginTransaction, s_cpu1EndTransaction, s_cpu1ReadNotWrite;
  wire [31:0] s_cpu1AddressData;
  wire [ 3:0] s_cpu1byteEnables;
  wire        s_cpu1DataValid;
  wire [ 7:0] s_cpu1BurstSize;
  wire        s_spm1Irq;

  assign s_cpu1CiDone = s_hdmiDone | s_swapByteDone | s_flashDone | s_cpuFreqDone | s_i2cCiDone | s_delayCiDone | s_pipelineCiDone | s_busErrorCounterCiDone | s_cameraSelectorCiDone | s_strobeControlCiDone;
  assign s_cpu1CiResult = s_hdmiResult | s_swapByteResult | s_flashResult | s_cpuFreqResult | s_i2cCiResult | s_delayResult | s_pipelineCiResult | s_busErrorCounterCiResult | s_cameraSelectorCiResult | s_strobeControlCiResult;

  or1420Top #(
      .NOP_INSTRUCTION(32'h1500FFFF)
  ) cpu1 (
      .cpuClock(s_systemClock),
      .cpuReset(s_cpuReset),
      .irq(1'b0),
      .cpuIsStalled(),
      .iCacheReqBus(s_cpu1IcacheRequestBus),
      .dCacheReqBus(s_cpu1DcacheRequestBus),
      .iCacheBusGrant(s_cpu1IcacheBusAccessGranted),
      .dCacheBusGrant(s_cpu1DcacheBusAccessGranted),
      .busErrorIn(s_busError),
      .busyIn(s_busy),
      .beginTransActionOut(s_cpu1BeginTransaction),
      .addressDataIn(s_addressData),
      .addressDataOut(s_cpu1AddressData),
      .endTransactionIn(s_endTransaction),
      .endTransactionOut(s_cpu1EndTransaction),
      .byteEnablesOut(s_cpu1byteEnables),
      .dataValidIn(s_dataValid),
      .dataValidOut(s_cpu1DataValid),
      .readNotWriteOut(s_cpu1ReadNotWrite),
      .burstSizeOut(s_cpu1BurstSize),
      .ciStart(s_cpu1CiStart),
      .ciReadRa(s_cpu1CiRa),
      .ciReadRb(s_cpu1CiRb),
      .ciWriteRd(s_cpu1CiRc),
      .ciN(s_cpu1CiN),
      .ciA(s_cpu1CiA),
      .ciB(s_cpu1CiB),
      .ciD(s_cpu1CiC),
      .ciDataA(s_cpu1CiDataA),
      .ciDataB(s_cpu1CiDataB),
      .ciResult(s_cpu1CiResult),
      .ciDone(s_cpu1CiDone)
  );

  assign s_cpu1CiCke = 1'b1;

  /*
   *
   * Here we define a custom instruction that determines the cpu-frequency
   *
   *
   */
  wire [31:0] s_cpuFreqValue;
  assign s_cpuFreqDone   = (s_cpu1CiN == 8'd4) ? s_cpu1CiStart : 1'b0;
  assign s_cpuFreqResult = (s_cpu1CiN == 8'd4 && s_cpu1CiStart == 1'b1) ? s_cpuFreqValue : 32'd0;

  processorId #(
      .processorId(1),
      .NumberOfProcessors(1),
      .ReferenceClockFrequencyInHz(50000000)
  ) cpuFreq (
      .clock(s_systemClock),
      .reset(s_cpuReset),
      .referenceClock(clock50MHz),
      .biosBypass(biosBypass),
      .procFreqId(s_cpuFreqValue)
  );

  /*
   *
   * Here we define a custom instruction that swaps bytes
   *
   */
  swapByte #(
      .customIntructionNr(8'd1)
  ) ise1 (
      .ciN(s_cpu1CiN),
      .ciDataA(s_cpu1CiDataA),
      .ciDataB(s_cpu1CiDataB),
      .ciStart(s_cpu1CiStart),
      .ciCke(s_cpu1CiCke),
      .ciDone(s_swapByteDone),
      .ciResult(s_swapByteResult)
  );
  /*
   *
   * Here we define a custom instruction that implements a simple I2C interface
   *
   */
  i2cCustomInstr #(
      .CLOCK_FREQUENCY(74250000),
      .I2C_FREQUENCY(400000),
      .CUSTOM_ID(8'd5)
  ) i2cm (
      .clock(s_systemClock),
      .reset(s_cpuReset),
      .ciStart(s_cpu1CiStart),
      .ciCke(s_cpu1CiCke),
      .ciN(s_cpu1CiN),
      .ciOppA(s_cpu1CiDataA),
      .ciDone(s_i2cCiDone),
      .result(s_i2cCiResult),
      .SDA(SDA),
      .SCL(SCL)
  );

  /*
   *
   * Here we define a custom instruction that implements a blocking micro-second(s) delay element
   *
   */
  delayIse #(
      .referenceClockFrequencyInHz(50000000),
      .customInstructionId(8'd6)
  ) delayMicro (
      .clock(s_systemClock),
      .referenceClock(clock50MHz),
      .reset(s_cpuReset),
      .ciStart(s_cpu1CiStart),
      .ciCke(s_cpu1CiCke),
      .ciN(s_cpu1CiN),
      .ciValueA(s_cpu1CiDataA),
      .ciValueB(s_cpu1CiDataB),
      .ciDone(s_delayCiDone),
      .ciResult(s_delayResult)
  );


  wire hrefFakeStatic, vsyncFakeStatic;
  wire [7:0] camDataFakeStatic;

  cameraFakeStatic fakeCameraStatic (
      .pclk(camPclk),
      .reset(s_reset),
      .href(hrefFakeStatic),
      .vsync(vsyncFakeStatic),  // low active!
      .camData(camDataFakeStatic)
  );

  wire hrefFakeMoving, vsyncFakeMoving;
  wire [7:0] camDataFakeMoving;
  cameraFakeMoving fakeCameraMoving (
      .pclk(camPclk),
      .reset(s_reset),
      .href(hrefFakeMoving),
      .vsync(vsyncFakeMoving),  // low active!
      .camData(camDataFakeMoving)
  );

  wire s_pipelineBeginTransaction, s_pipelineEndTransaction;

  wire hrefPipeline, vsyncPipeline;
  wire [7:0] camDataPipeline;

  wire hrefBin, vsyncBin;
  wire [7:0] camDataBin;

  pipeline #(
      .BINARIZE_CUSTOM_INSTRUCTION_ID(8'd11),
  ) blobDetector (
      .reset(s_reset),
      .pixelClock(camPclk),
      .href(hrefPipeline),
      .vsync(vsyncPipeline),  // low active
      .camData(camDataPipeline),

      .systemClock(s_systemClock),

      .ciStart(s_cpu1CiStart),
      .ciCke(s_cpu1CiCke),
      .ciN(s_cpu1CiN),
      .ciValueA(s_cpu1CiDataA),
      .ciValueB(s_cpu1CiDataB),
      .ciResult(s_pipelineCiResult),
      .ciDone(s_pipelineCiDone),

      .hrefBinOut(hrefBin),
      .vsyncBinOut(vsyncBin),
      .camDataBinOut(camDataBin),

      .spiSck(visionAddOnSpiSck),
      .spiMosi(visionAddOnSpiMosi),
      .spiMiso(visionAddOnSpiMiso),
      .spiTransferDone(visionAddOnSpiTransferDone)
  );

  busErrorCounter #(
      .CUSTOM_INSTRUCTION_ID(8'd10),
  ) bec (
      .reset(s_reset),
      .systemClock(s_systemClock),
      .busErrorIn(s_busError),
      .ciStart(s_cpu1CiStart),
      .ciCke(s_cpu1CiCke),
      .ciN(s_cpu1CiN),
      .ciValueA(s_cpu1CiDataA),
      .ciValueB(s_cpu1CiDataB),
      .ciResult(s_busErrorCounterCiResult),
      .ciDone(s_busErrorCounterCiDone),
  );

  cameraSelector #(
      .CUSTOM_INSTRUCTION_ID(8'd12)
  ) camSelector (
      .reset(s_reset),
      .pixelClock(camPclk),

      .hrefReal(camHref),
      .vsyncReal(~camVsync),
      .camDataReal(camData),

      .hrefFakeStatic(hrefFakeStatic),
      .vsyncFakeStatic(vsyncFakeStatic),
      .camDataFakeStatic(camDataFakeStatic),

      .hrefFakeMoving(hrefFakeMoving),
      .vsyncFakeMoving(vsyncFakeMoving),
      .camDataFakeMoving(camDataFakeMoving),

      .hrefBin(hrefBin),
      .vsyncBin(vsyncBin),
      .camDataBin(camDataBin),

      .hrefPipeline(hrefPipeline),
      .vsyncPipeline(vsyncPipeline),
      .camDataPipeline(camDataPipeline),

      .hrefScreen(visionAddOnCamHref),
      .vsyncScreen(visionAddOnCamVsync),
      .camDataScreen(visionAddOnCamData),

      .systemClock(s_systemClock),
      .ciStart(s_cpu1CiStart),
      .ciCke(s_cpu1CiCke),
      .ciN(s_cpu1CiN),
      .ciValueA(s_cpu1CiDataA),
      .ciValueB(s_cpu1CiDataB),
      .ciResult(s_cameraSelectorCiResult),
      .ciDone(s_cameraSelectorCiDone)
  );

  assign visionAddOnCamPclk = camPclk;

  strobeControl #(
      .CUSTOM_INSTRUCTION_ID(8'd14)
  ) strobeCtrl (
      .reset(s_reset),
      .pixelClock(camPclk),
      .trigger(~camVsync),
      .strobe(strobe),
      .systemClock(s_systemClock),
      .ciStart(s_cpu1CiStart),
      .ciCke(s_cpu1CiCke),
      .ciN(s_cpu1CiN),
      .ciValueA(s_cpu1CiDataA),
      .ciValueB(s_cpu1CiDataB),
      .ciResult(s_strobeControlCiResult),
      .ciDone(s_strobeControlCiDone)
  );

  wire n_s_reset;
  assign n_s_reset = ~s_reset;
  reg [7:0] visionAddOnSpiTxData = 'd42;
  reg visionAddOnSpiTxDataValid;
  wire visionAddOnSpiTxReady;
  wire [7:0] visionAddOnSpiRxData;
  wire visionAddOnSpiRxDataValid;

  edgeDetect sendSpiData (
      .clk(s_systemClock),
      .reset(s_reset),
      .s(visionAddOnSpiTxReady),
      .pos(visionAddOnSpiTxDataValid)
  );

  /*
   *
   * Here the hdmi controller is defined
   *
   */
  wire s_hdmiRequestBus, s_hdmiBusgranted, s_hdmiBeginTransaction;
  wire s_hdmiEndTransaction, s_hdmiDataValid, s_hdmiReadNotWrite;
  wire [ 3:0] s_hdmiByteEnables;
  wire [ 5:0] s_hdmiGreen;
  wire [ 7:0] s_hdmiBurstSize;
  wire [31:0] s_hdmiAddressData;

  assign hdmiGreen = s_hdmiGreen[5:1];

  screens #(
      .baseAddress(32'h50000020),
      .pixelClockFrequency(27'd74250000),
      .cursorBlinkFrequency(27'd1)
  ) hdmi (
      .pixelClockIn(s_pixelClock),
      .clock(s_systemClock),
      .reset(s_reset),
      .testPicture(1'b0),
      .dualText(1'b0),
      .ci1N(s_cpu1CiN),
      .ci1DataA(s_cpu1CiDataA),
      .ci1DataB(s_cpu1CiDataB),
      .ci1Start(s_cpu1CiStart),
      .ci1Cke(s_cpu1CiCke),
      .ci1Done(s_hdmiDone),
      .ci1Result(s_hdmiResult),
      .ci2N(8'd0),
      .ci2DataA(32'd0),
      .ci2DataB(32'd0),
      .ci2Start(1'b0),
      .ci2Cke(1'b0),
      .ci2Done(),
      .ci2Result(),
      .requestTransaction(s_hdmiRequestBus),
      .transactionGranted(s_hdmiBusgranted),
      .beginTransactionIn(s_beginTransaction),
      .endTransactionIn(s_endTransaction),
      .readNotWriteIn(s_readNotWrite),
      .dataValidIn(s_dataValid),
      .busErrorIn(s_busError),
      .addressDataIn(s_addressData),
      .byteEnablesIn(s_byteEnables),
      .burstSizeIn(s_burstSize),
      .beginTransactionOut(s_hdmiBeginTransaction),
      .endTransactionOut(s_hdmiEndTransaction),
      .dataValidOut(s_hdmiDataValid),
      .readNotWriteOut(s_hdmiReadNotWrite),
      .byteEnablesOut(s_hdmiByteEnables),
      .burstSizeOut(s_hdmiBurstSize),
      .addressDataOut(s_hdmiAddressData),
      .pixelClkX2(s_pixelClkX2),
      .hdmiRed(hdmiRed),
      .hdmiGreen(s_hdmiGreen),
      .hdmiBlue(hdmiBlue),
      .pixelClock(pixelClock),
      .horizontalSync(horizontalSync),
      .verticalSync(verticalSync),
      .activePixel(activePixel)
  );

  /*
   *
   * Here the spi-flash controller is defined
   *
   */
  wire [31:0] s_flashAddressData;
  wire s_flashEndTransaction, s_flashDataValid, s_flashBusError;
  spiBus #(
      .baseAddress(32'h04000000),
      .customIntructionNr(8'd2)
  ) flash (
      .clock(s_systemClock),
      .reset(s_reset),
      .spiScl(spiScl),
      .spiNCs(spiNCs),
      .spiSiIo0(spiSiIo0),
      .spiSoIo1(spiSoIo1),
      .spiIo2(spiIo2),
      .spiIo3(spiIo3),
      .ciN(s_cpu1CiN),
      .ciDataA(s_cpu1CiDataA),
      .ciDataB(s_cpu1CiDataB),
      .ciStart(s_cpu1CiStart),
      .ciCke(s_cpu1CiCke),
      .ciDone(s_flashDone),
      .ciResult(s_flashResult),
      .beginTransactionIn(s_beginTransaction),
      .endTransactionIn(s_endTransaction),
      .readNotWriteIn(s_readNotWrite),
      .busErrorIn(s_busError),
      .addressDataIn(s_addressData),
      .burstSizeIn(s_burstSize),
      .byteEnablesIn(s_byteEnables),
      .addressDataOut(s_flashAddressData),
      .endTransactionOut(s_flashEndTransaction),
      .dataValidOut(s_flashDataValid),
      .busErrorOut(s_flashBusError)
  );

  /*
   *
   * Here we define the bios
   *
   */
  wire [31:0] s_biosAddressData;
  wire s_biosBusError, s_biosDataValid, s_biosEndTransaction;
  bios start (
      .clock(s_systemClock),
      .reset(s_reset),
      .addressDataIn(s_addressData),
      .beginTransactionIn(s_beginTransaction),
      .endTransactionIn(s_endTransaction),
      .readNotWriteIn(s_readNotWrite),
      .busErrorIn(s_busError),
      .dataValidIn(s_dataValid),
      .byteEnablesIn(s_byteEnables),
      .burstSizeIn(s_burstSize),
      .addressDataOut(s_biosAddressData),
      .busErrorOut(s_biosBusError),
      .dataValidOut(s_biosDataValid),
      .endTransactionOut(s_biosEndTransaction)
  );

  /*
   *
   * Here we define the bus arbiter
   *
   */
  wire [31:0] s_busRequests, s_busGrants;
  wire s_arbBusError, s_arbEndTransaction;

  assign s_busRequests[31]            = s_cpu1DcacheRequestBus;
  assign s_busRequests[30]            = s_cpu1IcacheRequestBus;
  assign s_busRequests[29]            = s_hdmiRequestBus;
  assign s_busRequests[28:0]          = 'd0;

  assign s_cpu1DcacheBusAccessGranted = s_busGrants[31];
  assign s_cpu1IcacheBusAccessGranted = s_busGrants[30];
  assign s_hdmiBusgranted             = s_busGrants[29];

  busArbiter arbiter (
      .clock(s_systemClock),
      .reset(s_reset),
      .busRequests(s_busRequests),
      .busGrants(s_busGrants),
      .busErrorOut(s_arbBusError),
      .endTransactionOut(s_arbEndTransaction),
      .busIdle(s_busIdle),
      .snoopableBurst(s_snoopableBurst),
      .beginTransactionIn(s_beginTransaction),
      .endTransactionIn(s_endTransaction),
      .dataValidIn(s_dataValid),
      .addressDataIn(s_addressData[31:30]),
      .burstSizeIn(s_burstSize)
  );

  /*
   *
   * Here we define the bus architecture
   *
   */
  assign s_busError         = s_arbBusError | s_biosBusError | s_uart0BusError | s_uart1BusError | s_sdramBusError | s_flashBusError;
  assign s_beginTransaction = s_cpu1BeginTransaction | s_hdmiBeginTransaction;
  assign s_endTransaction   = s_cpu1EndTransaction | s_arbEndTransaction | s_biosEndTransaction | s_uart0EndTransaction |
                             s_uart1EndTransaction | s_sdramEndTransaction | s_hdmiEndTransaction | s_flashEndTransaction;
  assign s_addressData      = s_cpu1AddressData | s_biosAddressData | s_uart0AddressData | s_uart1AddressData | s_sdramAddressData |
                             s_hdmiAddressData | s_flashAddressData;
  assign s_byteEnables = s_cpu1byteEnables | s_hdmiByteEnables;
  assign s_readNotWrite = s_cpu1ReadNotWrite | s_hdmiReadNotWrite;
  assign s_dataValid        = s_cpu1DataValid | s_biosDataValid | s_uart0DataValid |  s_uart1DataValid | s_sdramDataValid | s_hdmiDataValid | 
                             s_flashDataValid;
  assign s_busy = s_sdramBusy;
  assign s_burstSize = s_cpu1BurstSize | s_hdmiBurstSize;

endmodule
