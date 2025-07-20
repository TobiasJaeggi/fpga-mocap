module featureTransferSpi #(
    // default for 640x480 resolution
    parameter integer unsigned NUM_BITS_X = 10,  // must be less or equal to 16
    parameter integer unsigned NUM_BITS_Y = 9  // must be less or equal to 16
) (
    input wire reset,
    // producer
    input wire pixelClock,
    input wire featureValid,
    input wire [((NUM_BITS_X + NUM_BITS_Y) * 2) - 1:0] featureVector,
    input wire cameraVsync,  // low active!
    // consumer
    input wire systemClock,
    // here the spi master interface is defined
    output wire spiSck,
    output wire spiMosi,
    input wire spiMiso,
    output reg spiTransferDone
);

  /*
   *
   * FEATURE BUFFER
   *
   */

  localparam integer unsigned FeatureWidth = (NUM_BITS_X + NUM_BITS_Y) * 2;
  localparam integer unsigned BytesPaddedFeatureVector = $rtoi($ceil(FeatureWidth / 8.0));
  localparam integer unsigned BitsPaddedFeatureVector = BytesPaddedFeatureVector * 8;

  wire switchBuffer;

  edgeDetect vSyncEdgeDetect (
      .clk(pixelClock),
      .reset(reset),
      .s(cameraVsync),
      .neg(switchBuffer)
  );

  // support for 2^7-2 boxes. Max buffer width is 8! Otherwise number of features can't be sent in one transfer over SPI
  localparam integer unsigned DoubleBufferAddressWidth = 7; // FIXME: 8 does not seems to work

  wire writeEnable;
  wire full;
  wire oneWriteLeft;
  wire [FeatureWidth-1:0] featureVectorSystemDomain;
  reg [DoubleBufferAddressWidth:0] bufferReadAddress; // one more bit for greater than comparison
  reg [DoubleBufferAddressWidth:0] bufferReadAddressNext;
  wire newData;
  wire [DoubleBufferAddressWidth-1:0] dataLength;

  assign writeEnable = featureValid && !(full || oneWriteLeft);

  doubleBuffer #(
      .DATA_WIDTH(FeatureWidth),
      .ADDRESS_WIDTH(DoubleBufferAddressWidth)
  ) featureBuffer (
      .reset(reset),
      // producer
      .writeClock(pixelClock),
      .writeEnable(writeEnable),
      .dataIn(featureVector),
      .full(full),
      .oneWriteLeft(oneWriteLeft),
      .switchBuffer(switchBuffer),
      // consumer
      .readClock(systemClock),
      .readPointer(bufferReadAddress[DoubleBufferAddressWidth-1:0]),
      .newData(newData),
      .dataLength(dataLength),
      .dataOut(featureVectorSystemDomain)
  );

  wire [BitsPaddedFeatureVector-1:0] paddedFeatureVector;
  localparam integer unsigned BitsPadding = BitsPaddedFeatureVector - FeatureWidth;
  wire [1:0] Padding = 'b0;
  assign paddedFeatureVector = {Padding, featureVectorSystemDomain};



  wire nReset =  ~reset;
  wire spiTxReady;
  reg spiTxDataValid;
  reg [7:0] spiTxData;
  wire spiRxDataValid;
  wire [7:0] spiRxData;
  SPI_Master #(
    .SPI_MODE(3), // CPOL = 1, CPHA = 1
    .CLKS_PER_HALF_BIT(2) // o_SPI_Clk = i_Clk / (2 * CLKS_PER_HALF_BIT)
  )
    spiMasterFeatureTransfer
  (
    // Control/Data Signals,
    .i_Rst_L(nReset),
    .i_Clk(systemClock),
    // TX (MOSI) Signals
    .i_TX_Byte(spiTxData), // Byte to transmit on MOSI
    .i_TX_DV(spiTxDataValid), // Data Valid Pulse with i_TX_Byte
    .o_TX_Ready(spiTxReady), // Transmit Ready for Byte
    // RX (MISO) Signals
    .o_RX_DV(spiRxDataValid), // Data Valid pulse (1 clock cycle)
    .o_RX_Byte(spiRxData), // Byte received on MISO
    // SPI Interface
    .o_SPI_Clk(spiSck),
    .i_SPI_MISO(spiMiso),
    .o_SPI_MOSI(spiMosi)
  );

  wire switchBufferSysDom;
  // crossing from pixel clock to system clock domain
  synchroFlop updateElementsInBufferCrossing (
      .clockIn(pixelClock),
      .clockOut(systemClock),
      .reset(reset),
      .D(switchBuffer),
      .Q(switchBufferSysDom)
  );

  reg [7:0] frameCount;
  always @(posedge systemClock, posedge reset) begin
    if (reset) begin
      frameCount <= 'd0;
    end else if(switchBufferSysDom == 'd1) begin
      frameCount <= frameCount + 'd1;
    end
  end

  /*
   *
   * SPI TRANSFER FSM
   *
   */
  localparam integer unsigned StateIdle = 0;
  localparam integer unsigned StateSendFrameCountWaitReady = 1;
  localparam integer unsigned StateSendFrameCountPulseValid = 2;
  localparam integer unsigned StateSendLengthWaitReady = 3;
  localparam integer unsigned StateSendLengthPulseValid = 4;
  localparam integer unsigned StateSendByteWaitReady = 5;
  localparam integer unsigned StateSendBytePulseValid = 6;
  localparam integer unsigned StateCheckBytesRemaining = 7;
  localparam integer unsigned StateIncrementAddress = 8;
  localparam integer unsigned StateCheckFeaturesRemaining = 9;
  localparam integer unsigned StateTransferDone = 10;
  localparam integer unsigned StateError = 11;
  localparam integer unsigned NumberOfStates = 12;

  reg [$clog2(NumberOfStates)-1:0] fsmState;
  reg [$clog2(NumberOfStates)-1:0] fsmStateNext;

  localparam integer unsigned BitsTxCount = $clog2(BytesPaddedFeatureVector);
  reg [BitsTxCount:0] txByteCount;
  reg [BitsTxCount:0] txByteCountNext;

  // FSN state and txCount register
  always @(posedge systemClock, posedge reset) begin
    if (reset) begin
      fsmState <= StateIdle;
      txByteCount <= 'd0;
      bufferReadAddress <= 'd0;
    end else begin
      fsmState <= fsmStateNext;
      txByteCount <= txByteCountNext;
      bufferReadAddress <= bufferReadAddressNext;
    end
  end

  // NSL
  wire featuresRemaining = bufferReadAddress < dataLength;
  wire bytesRemaining =  txByteCount < BytesPaddedFeatureVector;
  always_comb begin
    case (fsmState)
      StateIdle: begin
        fsmStateNext = (newData == 'b1) ? StateSendFrameCountWaitReady : StateIdle;
        txByteCountNext = 'd0;
        bufferReadAddressNext = 'd0;
      end
      StateSendFrameCountWaitReady: begin
        fsmStateNext = (newData == 'b1) ? StateError : (spiTxReady == 'b1) ? StateSendFrameCountPulseValid : StateSendFrameCountWaitReady;
        txByteCountNext = 'd0;
        bufferReadAddressNext = 'd0;
      end
      StateSendFrameCountPulseValid: begin
        fsmStateNext = (newData == 'b1) ? StateError : StateSendLengthWaitReady;
        txByteCountNext = 'd0;
        bufferReadAddressNext = 'd0;
      end
      StateSendLengthWaitReady: begin
        fsmStateNext = (newData == 'b1) ? StateError : (spiTxReady == 'b1) ? StateSendLengthPulseValid : StateSendLengthWaitReady;
        txByteCountNext = txByteCount;
        bufferReadAddressNext = bufferReadAddress;
      end
      StateSendLengthPulseValid: begin
        fsmStateNext = (newData == 'b1) ? StateError : ~featuresRemaining ? StateTransferDone : StateSendByteWaitReady;
        txByteCountNext = txByteCount;
        bufferReadAddressNext = bufferReadAddress;
      end
      StateSendByteWaitReady: begin
        fsmStateNext = (newData == 'b1) ? StateError : (spiTxReady == 'b1) ? StateSendBytePulseValid : StateSendByteWaitReady;
        txByteCountNext = txByteCount;
        bufferReadAddressNext = bufferReadAddress;
      end
      StateSendBytePulseValid: begin
        fsmStateNext = (newData == 'b1) ? StateError : StateCheckBytesRemaining;
        txByteCountNext = txByteCount + 'd1;
        bufferReadAddressNext = bufferReadAddress;
      end
      StateCheckBytesRemaining: begin
        fsmStateNext = (newData == 'b1) ? StateError : ~bytesRemaining ? StateIncrementAddress : StateSendByteWaitReady;
        txByteCountNext = txByteCount;
        bufferReadAddressNext = bufferReadAddress;
      end
      StateIncrementAddress: begin
        fsmStateNext = (newData == 'b1) ? StateError : StateCheckFeaturesRemaining;
        txByteCountNext = txByteCount;
        bufferReadAddressNext = bufferReadAddress + 'd1;
      end
      StateCheckFeaturesRemaining: begin
        fsmStateNext = (newData == 'b1) ? StateError : ~featuresRemaining ? StateTransferDone : StateSendByteWaitReady;
        txByteCountNext = 'd0;
        bufferReadAddressNext = bufferReadAddress;
      end
      StateTransferDone: begin
        fsmStateNext = (newData == 'b1) ? StateError : StateIdle;
        txByteCountNext = txByteCount;
        bufferReadAddressNext = bufferReadAddress;
      end
      StateError: begin
        fsmStateNext = StateIdle;
        txByteCountNext = 'd0;
        bufferReadAddressNext = 'd0;
      end
      default: begin
        fsmStateNext = StateError;
        txByteCountNext = txByteCount;
        bufferReadAddressNext = bufferReadAddress;
      end
    endcase
  end

  reg [7:0] dbg;
  // OL
  always_comb begin
    spiTxDataValid = ((fsmState == StateSendFrameCountPulseValid) || (fsmState == StateSendLengthPulseValid) || (fsmState == StateSendBytePulseValid)) ? 'b1 : 'b0;
    spiTxData = (fsmState == StateSendFrameCountPulseValid) ? (frameCount) :
                (fsmState == StateSendLengthPulseValid) ? (dataLength) : // number of features
                (fsmState == StateSendBytePulseValid) ? (paddedFeatureVector >> (txByteCount * 8)) & 8'hFF :
                'd0;
    spiTransferDone = (fsmState == StateTransferDone) ? 'b1 : 'b0;
  end

endmodule
