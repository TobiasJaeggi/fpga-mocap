module tb_featureTransferDma;
  localparam NUM_BITS_X = 4;
  localparam NUM_BITS_Y = 4;
  localparam CUSTOM_INSTRUCTION_ID = 42;
  localparam FEATURE_WIDTH = ((NUM_BITS_X + NUM_BITS_Y) * 2);
  reg reset = 0;
  // cam domain
  reg pixClock = 0;
  reg featureValid = 0;
  reg [FEATURE_WIDTH-1:0] featureVecCamDomain = 0;
  reg vSync = 0;
  // sys domain
  reg sysClock = 0;
  // bus
  wire requestBus;
  wire busGrant;
  wire beginTransaction;
  wire [31:0] addressData;
  wire endTransaction;
  wire [3:0] byteEnables;
  wire dataValid;
  wire [7:0] burstSize;
  reg busy = 0;
  reg busError = 0;
  // ci
  reg ciStart = 0;
  reg ciCke = 0;
  reg [7:0] ciN = 0;
  reg [31:0] ciValueA = 'hffff;
  reg [31:0] ciValueB = 0;
  wire [31:0] ciResult = 0;
  wire ciDone;
  wire dataReady;
  featureTransferDma #(
      .CUSTOM_INSTRUCTION_ID(CUSTOM_INSTRUCTION_ID),
      .NUM_BITS_X(NUM_BITS_X),
      .NUM_BITS_Y(NUM_BITS_Y)
  ) ft (
      .reset(reset),
      .pixelClock(pixClock),
      .featureValid(featureValid),
      .featureVector(featureVecCamDomain),
      .cameraVsync(vSync),
      .systemClock(sysClock),
      // bus interface
      .requestBus(requestBus),
      .busGrant(busGrant),
      .beginTransactionOut(beginTransaction),
      .addressDataOut(addressData),
      .endTransactionOut(endTransaction),
      .byteEnablesOut(byteEnables),
      .dataValidOut(dataValid),
      .burstSizeOut(burstSize),
      .busyIn(busy),
      .busErrorIn(busError),
      // ci
      .ciStart(ciStart),
      .ciCke(ciCke),
      .ciN(ciN),
      .ciValueA(ciValueA),
      .ciValueB(ciValueB),
      .ciResult(ciResult),
      .ciDone(ciDone),
      // irq
      .dataReady(dataReady)
  );
  
  reg requestBusDelayed;
  always @(posedge sysClock) begin
  if (reset) requestBusDelayed <= 0;
  else requestBusDelayed <= requestBus;
  end

  // best case bus scenario
  assign busGrant = requestBus;

  always begin
    #5 sysClock = ~sysClock;
  end

  always begin
    #8 pixClock = ~pixClock;
  end

  localparam CI_A_READ_LENGTH = 0;
  localparam CI_A_WRITE_ADDRESS = 1;
  localparam CI_A_START_STOP = 2;
  localparam CI_A_READ_ADDRRESS = 3;
  localparam CI_A_READ_FREQ = 4;

  task getBufferLength;
    begin
      @(posedge sysClock) #0 ciStart = 1;
      #0 ciCke = 1;
      #0 ciN = CUSTOM_INSTRUCTION_ID;
      #0 ciValueA = CI_A_READ_LENGTH;
      #0 ciValueB = 32'h0;
      @(posedge sysClock) #0 ciStart = 0;
      #0 ciN = 0;
      #0 ciCke = 0;
      #0 ciValueA = 0;
      #0 ciValueB = 0;
    end
  endtask

  task setFeatureBuffer;
    begin
      @(posedge sysClock) #0 ciStart = 1;
      #0 ciCke = 1;
      #0 ciN = CUSTOM_INSTRUCTION_ID;
      #0 ciValueA = CI_A_WRITE_ADDRESS;
      #0 ciValueB = 32'h0000ABCD;
      @(posedge sysClock) #0 ciStart = 0;
      #0 ciN = 0;
      #0 ciCke = 0;
      #0 ciValueA = 0;
      #0 ciValueB = 0;
    end
  endtask

  task enableTransfer;
    begin
      @(posedge sysClock) #0 ciStart = 1;
      #0 ciCke = 1;
      #0 ciN = CUSTOM_INSTRUCTION_ID;
      #0 ciValueA = CI_A_START_STOP;
      #0 ciValueB = 32'h1;
      @(posedge sysClock) #0 ciStart = 0;
      #0 ciN = 0;
      #0 ciCke = 0;
      #0 ciValueA = 0;
      #0 ciValueB = 0;
    end
  endtask

  task disableTransfer;
    begin
      @(posedge sysClock) #0 ciStart = 1;
      #0 ciCke = 1;
      #0 ciN = CUSTOM_INSTRUCTION_ID;
      #0 ciValueA = CI_A_START_STOP;
      #0 ciValueB = 32'h0;
      @(posedge sysClock) #0 ciStart = 0;
      #0 ciN = 0;
      #0 ciCke = 0;
      #0 ciValueA = 0;
      #0 ciValueB = 0;
    end
  endtask

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

  task syncBusy;
    begin
      @(posedge pixClock) #0 vSync = 0;
      @(posedge busGrant) #40 busy = 1;
      #10 busy = 0; 
      #10 busy = 1; 
      #20 busy = 0; 
      @(posedge pixClock) #0 vSync = 1;
    end
  endtask

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_featureTransferDma);
    reset = 1;
    pixClock = 0;
    featureValid = 0;
    featureVecCamDomain = 0;
    vSync = 1;
    sysClock = 0;
    #10 reset = 0;
    sync();
    #10
    sync();
    #10 getBufferLength();
    #10 setFeatureBuffer();
    #10 enableTransfer();
    #10 #10 featureVecCamDomain = 'h134A;
    writeFeature();
    #10 sync();
    #80 featureVecCamDomain = 'h2468;
    writeFeature();
    #10 featureVecCamDomain = 'hAF38;
    writeFeature();
    #10 sync();
    #80 featureVecCamDomain = 'h0156;
    writeFeature();
    #10 featureVecCamDomain = 'hAC5E;
    writeFeature();
    #10 featureVecCamDomain = 'h8F6F;
    writeFeature();
    #10 sync();
    #80 featureVecCamDomain = 'h4321;
    writeFeature();
    #10 featureVecCamDomain = 'h8765;
    writeFeature();
    #10 featureVecCamDomain = 'hCBA9;
    writeFeature();
    #10 featureVecCamDomain = 'h0FED;
    writeFeature();
    #10 sync();
    #180 
    #10 reset = 1;
    #10 reset = 0;
    featureVecCamDomain = 'h1718;
    writeFeature();
    #10 featureVecCamDomain = 'h6829;
    writeFeature();
    #10 featureVecCamDomain = 'hAF36;
    writeFeature();
    #10 sync();
    #10 disableTransfer();
    #10 sync();
    #10 sync();
    #10 setFeatureBuffer();
    #10 enableTransfer();
    #10 featureVecCamDomain = 'h1234;
    writeFeature();
    #10 featureVecCamDomain = 'h5678;
    writeFeature();
    #10 featureVecCamDomain = 'h9ABC;
    writeFeature();
    #10 featureVecCamDomain = 'hDEF0;
    writeFeature();
    #10 syncBusy();
    #80 featureVecCamDomain = 'h1111;
    writeFeature();
    #10 featureVecCamDomain = 'h2222;
    writeFeature();
    #10 featureVecCamDomain = 'h3333;
    writeFeature();
    #10 featureVecCamDomain = 'h4444;
    writeFeature();
    #10 sync();
    #10
    @(posedge beginTransaction) #3 busError = 1;
    #27
    busError = 0;
    #160 $finish;
  end

endmodule
