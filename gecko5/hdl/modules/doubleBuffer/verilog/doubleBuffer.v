module doubleBuffer #(
    parameter DATA_WIDTH = 10,
    parameter ADDRESS_WIDTH = 8 // FIFO depth = 2^ADDRESS_WIDTH - 1 (-1 could be optimized but is used to prevent wrap around of addr counter)
) (
    input wire reset,  // async
    // producer
    input wire writeClock,
    input wire writeEnable,
    input wire [DATA_WIDTH-1:0] dataIn,
    output wire full, // synched with writeClock, true once the last element was written to buffer. Writing to buffer if full will result in undefined behavior. use oneWriteLeft to know when to preemitvely stop writing to buffer.
    output wire oneWriteLeft, // synched with writeClock, true in the clock cycle where one write is left.
    input wire switchBuffer,  // synched with writeClock, consumer gets jibberish if still reading!
    // both assert and deassert of readyForSwitch are delayed. So only build your logic arround rising edge of readyForSwitch
    // TODO: emptyProducerDomain to know when switch is allowed? Since consumers empty can't change back from 0 to 1 without a buffer switch, producer can be sure that no read is in progress
    // consumer
    input wire readClock,
    input wire [ADDRESS_WIDTH-1:0] readPointer,
    output wire [ADDRESS_WIDTH-1:0] dataLength,
    output wire newData,
    output wire [DATA_WIDTH-1:0] dataOut
);

  parameter integer unsigned ADDRESS_MAX = (2 << (ADDRESS_WIDTH - 1)) - 1; // -1 to prevent wrap around of writePointer so that it can be used to define dataLength

  // producer clock domain
  reg  fullLatch;
  wire resetWritePointer;
  assign resetWritePointer = switchBuffer;

  reg [ADDRESS_WIDTH-1:0] writePointer;
  wire oneWriteLeftProducer;

  wire maxReachedWrite;

  always @(posedge writeClock or posedge reset) begin
    if (reset) begin
      writePointer <= 0;
      fullLatch <= 0;
    end else begin
      writePointer <= (resetWritePointer == 1) ? 0 :
                      (maxReachedWrite == 1) ? writePointer :
                      (writeEnable == 1) ? (writePointer + 1) :
                      writePointer;
      fullLatch <= (switchBuffer == 1) ? 0 :
                   (maxReachedWrite == 1) ? 1 :
                   fullLatch; // reset by swap, set by maxReachedWrite
    end
  end

  assign maxReachedWrite = (writePointer == ADDRESS_MAX);
  assign oneWriteLeftProducer = (writePointer == (ADDRESS_MAX - 1));
  assign full = maxReachedWrite || fullLatch || resetWritePointer;
  assign oneWriteLeft = oneWriteLeftProducer;

  // crossing from producer to consumer clock domain
  reg [ADDRESS_WIDTH-1:0] dataLengthProducer;
  reg switchBufferProducer;
  wire switchBufferConsumer;
  reg writeBufferNewData;
  always @(posedge writeClock or posedge reset) begin
    if (reset) begin
      dataLengthProducer <= 0;
      switchBufferProducer <= 0;
      writeBufferNewData <= 0;
    end else begin
      // TODO: how to guarantee that dataLengthProducer is not updated while dataLengthConsumer is still reading?
      // a round trip through the consumer clock domain could be used. switchBuffer would no longer be an instant command but rather a request which is granted after the consumer has received the read max pointer
      // ... over-engineering?
      // same method might be needed for readyForSwitch
      dataLengthProducer <= (switchBuffer == 1) ? writePointer : dataLengthProducer;
      switchBufferProducer <= switchBuffer;
      writeBufferNewData <= (switchBuffer == 1) ? 0 : (writeEnable == 1) ? 1 : writeBufferNewData;
    end
  end

  // crossing from producer to consumer clock domain

  synchroFlop updateElementsInBufferCrossing (
      .clockIn(writeClock),
      .clockOut(readClock),
      .reset(reset),
      .D(switchBufferProducer),
      .Q(switchBufferConsumer)
  );

  // consumer clock domain
  reg [ADDRESS_WIDTH-1:0] dataLengthConsumer;
  always @(posedge readClock or posedge reset) begin
    if (reset) begin
      dataLengthConsumer <= 0;
    end else begin
      dataLengthConsumer <= (switchBufferConsumer == 1) ? dataLengthProducer : dataLengthConsumer;
    end
  end

  assign dataLength = dataLengthConsumer;
  assign newData = switchBufferConsumer;

  // double buffers and their mapping
  wire writeEnable_0;
  wire writeEnable_1;
  wire [DATA_WIDTH-1:0] dataOut_0;
  wire [DATA_WIDTH-1:0] dataOut_1;

  sramDp #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDRESS_WIDTH(ADDRESS_WIDTH)
  ) sramDp0 (
      .clockA(writeClock),
      .writeEnableA(writeEnable_0),
      .addressA(writePointer),
      .dataInA(dataIn),
      .clockB(readClock),
      .addressB(readPointer),
      .dataOutB(dataOut_0)
  );

  sramDp #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDRESS_WIDTH(ADDRESS_WIDTH)
  ) sramDp1 (
      .clockA(writeClock),
      .writeEnableA(writeEnable_1),
      .addressA(writePointer),
      .dataInA(dataIn),
      .clockB(readClock),
      .addressB(readPointer),
      .dataOutB(dataOut_1)
  );

  // handle mapping

  reg mappingState;
  reg mappingStateNext;

  always @(posedge writeClock or posedge reset) begin
    if (reset) begin
      mappingState <= 0;
    end else begin
      mappingState <= mappingStateNext;
    end
  end

  localparam DATA_IN_0_DATA_OUT_1 = 0;
  localparam DATA_IN_1_DATA_OUT_0 = 1;

  // NSL
  always @(*) begin
    case (mappingState)
      DATA_IN_0_DATA_OUT_1:
      mappingStateNext <= (switchBuffer == 1) ? DATA_IN_1_DATA_OUT_0 : DATA_IN_0_DATA_OUT_1;
      DATA_IN_1_DATA_OUT_0:
      mappingStateNext <= (switchBuffer == 1) ? DATA_IN_0_DATA_OUT_1 : DATA_IN_1_DATA_OUT_0;
    endcase
  end

  // OL
  assign writeEnable_0 = (mappingState == DATA_IN_0_DATA_OUT_1) ? writeEnable : 0;
  assign writeEnable_1 = (mappingState == DATA_IN_1_DATA_OUT_0) ? writeEnable : 0;
  assign dataOut = (mappingState == DATA_IN_0_DATA_OUT_1) ? dataOut_1 : dataOut_0;

endmodule
