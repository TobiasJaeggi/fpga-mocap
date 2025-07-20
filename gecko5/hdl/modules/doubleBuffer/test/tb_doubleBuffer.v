module tb_doubleBuffer;
  localparam DATA_WIDTH = 4;
  localparam ADDRESS_WIDTH = 2;
  // async
  reg reset;
  // producer
  reg writeClock;
  reg writeEnable;
  reg [DATA_WIDTH-1:0] writeData;
  wire full;
  wire oneWriteLeft;
  reg switchBuffer;
  // consumer
  reg readClock;
  reg [ADDRESS_WIDTH-1:0] readAddress;
  wire [ADDRESS_WIDTH-1:0] dataLength;
  wire newData;
  wire [DATA_WIDTH-1:0] dataOut;

  doubleBuffer #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDRESS_WIDTH(ADDRESS_WIDTH)
  ) doubleBuffer_test (
      .reset(reset),
      .writeClock(writeClock),
      .writeEnable(writeEnable),
      .dataIn(writeData),
      .full(full),
      .oneWriteLeft(oneWriteLeft),
      .switchBuffer(switchBuffer),
      .readClock(readClock),
      .readPointer(readAddress),
      .dataLength(dataLength),
      .newData(newData),
      .dataOut(dataOut)
  );

  always begin
    #2 writeClock = ~writeClock;
  end
  always begin
    #1 readClock = ~readClock;
  end

  task writePattern0;
    begin
      @(posedge writeClock);
      #0 writeData = 4'h1;
      @(posedge writeClock);
      #0 writeData = 4'h2;
      @(posedge writeClock);
      #0 writeData = 4'h3;
      @(posedge writeClock);
      #0 writeEnable = 0;
    end
  endtask

  task writePattern1;
    begin
      @(posedge writeClock);
      #0 writeData = 4'h4;
      #0 writeEnable = 1;
      @(posedge writeClock);
      #0 writeData = 4'h5;
      @(posedge writeClock);
      #0 writeData = 4'h6;
      @(posedge writeClock);
      #0 writeEnable = 0;
    end
  endtask

  task writePattern2;
    begin
      @(posedge writeClock);
      #0 writeData = 4'h8;
      #0 writeEnable = 1;
      @(posedge writeClock);
      #0 writeData = 4'h9;
      @(posedge writeClock);
      #0 writeData = 4'ha;
      @(posedge writeClock);
      #0 writeEnable = 0;
    end
  endtask

  task writePattern3;
    begin
      @(negedge writeClock);
      #0 writeData = 4'hc;
      #0 writeEnable = 1;
      @(posedge writeClock);
      #0 writeData = 4'hd;
      @(posedge writeClock);
      #0 writeEnable = 0;
      #3 @(posedge writeClock);
      #0 writeEnable = 1;
      #0 writeData = 4'he;
      @(posedge writeClock);
      #0 writeEnable = 0;
    end
  endtask

  task writePatternHalf;
    begin
      @(posedge writeClock);
      #0 writeData = 4'h1;
      #0 writeEnable = 1;
      @(posedge writeClock);
      #0 writeData = 4'h3;
      @(posedge writeClock);
      #0 writeEnable = 0;
    end
  endtask

  task writePatternQuarter;
    begin
      @(posedge writeClock);
      #0 writeData = 4'hb;
      #0 writeEnable = 1;
      @(posedge writeClock);
      #0 writeEnable = 0;
    end
  endtask

  task swapNonBlocking;
  begin
    @(posedge writeClock);
    #0 switchBuffer = 1;
    @(posedge writeClock);
    #0 switchBuffer = 0;
  end
endtask


  task swapBlocking;
    begin
      @(posedge writeClock);
      #0 switchBuffer = 1;
      @(posedge writeClock);
      #0 switchBuffer = 0;
      wait(readAddress == dataLength) // wait for read to complete
      @(negedge writeClock);
    end
  endtask

  reg [ADDRESS_WIDTH-1:0] maxAddr = 0;
  always begin  // read
    @(posedge newData);
    maxAddr = dataLength;
    @(posedge readClock);
    readAddress = 0;
    @(negedge readClock);
    while (readAddress < maxAddr) begin
      @(posedge readClock);
      readAddress = readAddress + 1;
      @(negedge readClock);
    end
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_doubleBuffer);
    reset = 1;
    writeClock = 0;
    writeEnable = 0;
    writeData = 0;
    switchBuffer = 0;
    readClock = 0;
    readAddress = 'hff;
    #10 reset = 0;

    #10
    // write nothing
    swapNonBlocking();

    writePattern1();
    swapBlocking();
    writePattern2();
    swapBlocking();
    writePattern3();
    swapBlocking();
    writePatternHalf();
    swapBlocking();
    writePattern1();
    swapBlocking();
    swapBlocking();
    writePatternQuarter();
    swapBlocking();
    swapBlocking();
    wait(readAddress == dataLength)
    $finish;
  end

endmodule
