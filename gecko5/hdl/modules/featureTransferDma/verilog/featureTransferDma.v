module featureTransferDma #(
    parameter [7:0] CUSTOM_INSTRUCTION_ID = 'd0,
    // default for 640x480 resolution
    parameter NUM_BITS_X = 10,  // must be less or equal to 16
    parameter NUM_BITS_Y = 9,  // must be less or equal to 16
    parameter SYSTEMCLOCK_IN_HZ = 74250000
) (
    input wire reset,  // sync!
    // producer
    input wire pixelClock,
    input wire featureValid,
    input wire [((NUM_BITS_X + NUM_BITS_Y) * 2) - 1:0] featureVector,
    input wire cameraVsync,  // low active!
    // consumer
    input wire systemClock,
    // here the bus master interface is defined
    output wire requestBus,
    input wire busGrant,
    output reg beginTransactionOut,
    output wire [31:0] addressDataOut,
    output reg endTransactionOut,
    output reg [3:0] byteEnablesOut,
    output wire dataValidOut,
    output reg [7:0] burstSizeOut,
    input wire busyIn,
    input wire busErrorIn,
    // custom instruction interface
    input wire ciStart,
    input wire ciCke,  //TODO: whats this?
    input wire [7:0] ciN,
    input wire [31:0] ciValueA,
    input wire [31:0] ciValueB,
    output wire [31:0] ciResult,
    output wire ciDone,
    output wire [15:0] analogDiscovery,
    // irq
    output reg dataReady,
    output reg [31:0] numberOfFeatures
);

  /*
   *
   * FEATURE BUFFER
   *
   */

  localparam FEATURE_WIDTH = (NUM_BITS_X + NUM_BITS_Y) * 2;

  wire switchBuffer;

  edgeDetect vSyncEdgeDetect (
      .clk(pixelClock),
      .reset(reset),
      .s(cameraVsync),
      .neg(switchBuffer)
  );
  // TODO: make sure buffer can be switched during vsync pulse
  // TODO: do we need to delay the buffer switch for some clock cycles for the consumer to have enough time to read the data?

  localparam DOUBLE_BUFFER_ADDRESS_WIDTH = 4;  // support for 16 boxes. Be aware that bigger width than burst transfer size is untested.

  wire writeEnable;
  wire full;
  wire oneWriteLeft;
  wire [FEATURE_WIDTH-1:0] featureVectorSystemDomain;
  reg [DOUBLE_BUFFER_ADDRESS_WIDTH-1:0] bufferReadAddress;
  wire newData;
  wire [DOUBLE_BUFFER_ADDRESS_WIDTH-1:0] bufferReadAddressMax;

  assign writeEnable = featureValid && !(full || oneWriteLeft);

  doubleBuffer #(
      .DATA_WIDTH(FEATURE_WIDTH),
      .ADDRESS_WIDTH(DOUBLE_BUFFER_ADDRESS_WIDTH)
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
      .readPointer(bufferReadAddress),
      .newData(newData),
      .readPointerMax(bufferReadAddressMax),
      .dataOut(featureVectorSystemDomain)
  );

  wire [NUM_BITS_X-1:0] x0 = featureVectorSystemDomain[((2 * (NUM_BITS_X + NUM_BITS_Y)) - 1):(NUM_BITS_X + (2 * NUM_BITS_Y))];
  wire [NUM_BITS_X-1:0] x1 = featureVectorSystemDomain[((NUM_BITS_X+(2*NUM_BITS_Y))-1):(2*NUM_BITS_Y)];
  wire [NUM_BITS_Y-1:0] y0 = featureVectorSystemDomain[((2*NUM_BITS_Y)-1):(NUM_BITS_Y)];
  wire [NUM_BITS_Y-1:0] y1 = featureVectorSystemDomain[(NUM_BITS_Y-1):0];
  wire [15:0] centerOfMassX = x0 + ((x1 - x0) / 2);
  wire [15:0] centerOfMassY = y0 + ((y1 - y0) / 2);

  // alligned to 16 bit per coordinate
  // MSB [centerOfMassY centerOfMassX] LSB
  // [31:16]: centerOfMassY
  // [15: 0]: centerOfMassX
  wire [31:0] paddedFeatureVector;
  assign paddedFeatureVector = {centerOfMassY, centerOfMassX};

  /*
   * CUSTOM INSTRUCTION
   *
   * different ci commands:
   * ciValueA:    Description:
   *     0        Read feature buffer length
   *     1        Write feature buffer address (ciValueB[31:0])
   *     2        Start/stop feature transfer (ciValueB[0])
   *     3        Read back feature buffer address 
   *     4        Read pipeline fequency (only based on last period)
   *
   */

  localparam CI_A_READ_LENGTH = 0;
  localparam CI_A_WRITE_ADDRESS = 1;
  localparam CI_A_START_STOP = 2;
  localparam CI_A_READ_ADDRRESS = 3;
  localparam CI_A_READ_FREQ = 4;

  wire isMyCi = (ciN == CUSTOM_INSTRUCTION_ID) ? ciStart & ciCke : 'b0;
  reg [31:0] featureBufferBase;
  reg featureTransferActive;
  reg [31:0] frequencyCounter, frequency;

  always @(posedge systemClock) begin  //FIXME: async reset
    if (reset) begin
      featureBufferBase <= 'd0;
      featureTransferActive <= 'b0;
      frequencyCounter <= 'd0;
      frequency <= 'd0;
    end else begin
      featureBufferBase <= (isMyCi == 'b1 && (ciValueA == CI_A_WRITE_ADDRESS)) ? ciValueB : featureBufferBase;
      //featureBufferBase <= (isMyCi == 'b1 && (ciValueA == CI_A_WRITE_ADDRESS)) ? {ciValueB[31:2],'d0} : featureBufferBase;
      featureTransferActive <= (isMyCi == 'b1 && (ciValueA == CI_A_START_STOP)) ? ciValueB[0] : featureTransferActive;
      frequencyCounter <= (newData == 'b1) ? 'd0 : frequencyCounter + 1;
      frequency <= (newData == 'b1) ? (SYSTEMCLOCK_IN_HZ / frequencyCounter) : frequency;
    end
  end

  reg [31:0] selectedResult = 'd0; // intentionally set to 0 since process does not define a reset value

  assign ciDone   = isMyCi;
  assign ciResult = (isMyCi == 'b0) ? 'd0 : selectedResult;

  always @(*) begin
    case (ciValueA)
      CI_A_READ_LENGTH: selectedResult <= (('d2 ** DOUBLE_BUFFER_ADDRESS_WIDTH) - 'd1);
      CI_A_READ_ADDRRESS: selectedResult <= featureBufferBase;
      CI_A_READ_FREQ: selectedResult <= frequency;
      default: selectedResult <= 'd0;
    endcase
  end

  /*
   *
   * DMA
   *
   */
  /*
  typedef enum {
    STATE_IDLE,
    STATE_REQUEST_BUS,
    STATE_INIT_BURST,
    STATE_DO_BURST,
    STATE_SLAVE_BUSY,
    STATE_END_TRANS
  } state;

  state fsmState, fsmStateNext;
*/
  localparam STATE_IDLE = 0;
  localparam STATE_SAVE_NUMBER_OF_FEATURES = 1;
  localparam STATE_REQUEST_BUS = 2;
  localparam STATE_INIT_BURST = 3;
  localparam STATE_DO_BURST = 4;
  localparam STATE_SLAVE_BUSY = 5;
  localparam STATE_END_TRANS = 6;
  localparam STATE_TRANSFER_COMPLETE = 7;

  localparam NUMBER_OF_STATES = 8;

  reg [$clog2(NUMBER_OF_STATES)-1:0] fsmState;
  reg [$clog2(NUMBER_OF_STATES)-1:0] fsmStateNext = STATE_IDLE;  //TODO: wire?

  //TODO: fire interrupt upon completed transfer, pass number of features as well

  reg [31:0] busAddress, addressData;
  reg [8:0] burstCount;  // one more bit to detect values greater than max
  reg dataValid;
  wire doWrite = ((fsmState == STATE_DO_BURST) && burstCount[8] == 1'b0) ? ~busyIn : 1'b0;
  wire [31:0] busAddressNext = (reset == 1'b1 || switchBuffer == 1'b1) ? featureBufferBase : 
                               (doWrite == 1'b1) ? busAddress + 32'd4 : // 1 data element is 32 bit = 4 byte
  busAddress;
  wire [7:0] remainingBytes = (bufferReadAddressMax - bufferReadAddress) + 1;
  wire [7:0] burstSizeNext = ((fsmState == STATE_INIT_BURST) && remainingBytes > 9'd16) ? 8'd16 : remainingBytes[7:0];

  wire bufferEmpty = (bufferReadAddress > bufferReadAddressMax) ? 'b1 : 'b0;
  assign requestBus     = (fsmState == STATE_REQUEST_BUS) ? 1'b1 : 1'b0;
  assign addressDataOut = addressData;
  assign dataValidOut   = dataValid;

  always @(posedge systemClock) begin
    if (reset) begin
      fsmState <= STATE_IDLE;
    end else begin
      fsmState <= fsmStateNext;
    end
  end

  // NSL
  always @(*) begin
    case (fsmState)
      STATE_IDLE:
      fsmStateNext <= (newData == 'b1 && featureTransferActive == 'b1) ? STATE_SAVE_NUMBER_OF_FEATURES : STATE_IDLE ;
      STATE_SAVE_NUMBER_OF_FEATURES: fsmStateNext <= STATE_REQUEST_BUS;
      STATE_REQUEST_BUS: fsmStateNext <= (busGrant == 'b1) ? STATE_INIT_BURST : STATE_REQUEST_BUS;
      STATE_INIT_BURST: fsmStateNext <= STATE_DO_BURST;
      STATE_DO_BURST:
      fsmStateNext <= (busErrorIn == 'b1) ? STATE_END_TRANS:
                      (burstCount[8] == 'b1 && busyIn == 'b0) ? STATE_END_TRANS :
                      STATE_DO_BURST;
      STATE_END_TRANS:
      fsmStateNext <= (bufferEmpty == 'b0) ? STATE_REQUEST_BUS : STATE_TRANSFER_COMPLETE;
      STATE_TRANSFER_COMPLETE: fsmStateNext <= STATE_IDLE;
      default: fsmStateNext <= STATE_IDLE;
    endcase
  end

  always @(posedge systemClock) begin
    busAddress <= busAddressNext;
    beginTransactionOut <= (fsmState == STATE_INIT_BURST) ? 'd1 : 'd0;
    byteEnablesOut <= (fsmState == STATE_INIT_BURST) ? 'hF : 'd0;
    addressData <= (fsmState == STATE_INIT_BURST) ? busAddress : // TODO: write number of detected features as part of dma transfer
    (doWrite == 'b1) ? paddedFeatureVector : (busyIn == 'b1) ? addressData : 'd0;
    dataValid <= (doWrite == 'b1) ? 'b1 : (busyIn == 'b1) ? dataValid : 'b0;
    endTransactionOut <= (fsmState == STATE_END_TRANS) ? 'b1 : 'b0;
    burstSizeOut <= (fsmState == STATE_INIT_BURST) ? burstSizeNext - 8'd1 : 8'd0;
    burstCount <= (fsmState == STATE_INIT_BURST) ? burstSizeNext - 8'd1 :
                  (doWrite == 'b1) ? burstCount - 9'd1 :
                  burstCount;
    bufferReadAddress  <= (fsmState == STATE_IDLE) ? 'd0 : (doWrite == 'b1) ? bufferReadAddress + 'd1 : bufferReadAddress;
    dataReady <= (fsmState == STATE_TRANSFER_COMPLETE) ? 'b1 : 'b0;
    numberOfFeatures <= (fsmState == STATE_SAVE_NUMBER_OF_FEATURES) ? (bufferReadAddressMax + 'd1) : numberOfFeatures;
  end

endmodule
