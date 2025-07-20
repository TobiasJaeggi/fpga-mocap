module tb_waitForTransfer;
  localparam CUSTOM_INSTRUCTION_ID = 42;

  reg reset = 0;
  // sys domain
  reg clock = 0;
  // feature transfer
  reg dataReady = 0;
  reg [31:0] numberOfFeatures = 0;
  // ci
  reg ciStart = 0;
  reg ciCke = 0;
  reg [7:0] ciN = 0;
  reg [31:0] ciValueA = 'hffff;
  reg [31:0] ciValueB = 0;
  wire [31:0] ciResult = 0;
  wire ciDone;
  waitForTransfer #(
      .CUSTOM_INSTRUCTION_ID(CUSTOM_INSTRUCTION_ID)
  ) wft (
      .reset(reset),
      .clock(clock),
      // feature transfer
      .dataReady(dataReady),
      .numberOfFeatures(numberOfFeatures),
      // ci
      .ciStart(ciStart),
      .ciCke(ciCke),
      .ciN(ciN),
      .ciValueA(ciValueA),
      .ciValueB(ciValueB),
      .ciResult(ciResult),
      .ciDone(ciDone)
  );
  
  always begin
    #5 clock = ~clock;
  end

  task getNumberOfFeatures;
    begin
      @(posedge clock) #0 ciStart = 1;
      #0 ciCke = 1;
      #0 ciN = CUSTOM_INSTRUCTION_ID;
      #0 ciValueA = 32'h0;
      #0 ciValueB = 32'h0;
      @(posedge clock) #0 ciStart = 0;
      #0 ciN = 0;
      #0 ciCke = 0;
      #0 ciValueA = 0;
      #0 ciValueB = 0;
    end
  endtask


  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_waitForTransfer);
    reset = 1;
    clock = 0;
    numberOfFeatures = 0;
    dataReady = 0;
    #10 reset = 0;

    getNumberOfFeatures();

    #10 numberOfFeatures = 'd12;
    @(posedge clock) #0 dataReady = 'b1;
    #1
    @(posedge clock) #0 dataReady = 'b0;
 
    // no ci access
    #10 numberOfFeatures = 'd22;
    @(posedge clock) #0 dataReady = 'b1;
    #1
    @(posedge clock) #0 dataReady = 'b0;

    getNumberOfFeatures();

    #10 numberOfFeatures = 'd32;
    @(posedge clock) dataReady = 'b1;
    #1
    @(posedge clock) dataReady = 'b0;
    

    #10 $finish;
   end

endmodule
