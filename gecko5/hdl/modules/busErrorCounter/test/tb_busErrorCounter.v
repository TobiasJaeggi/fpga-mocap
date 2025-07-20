module tb_busErrorCounter;
  localparam CUSTOM_INSTRUCTION_ID = 42;
  reg reset = 0;
  reg sysClock = 0;
  reg busError = 0;
  // ci
  reg ciStart = 0;
  reg ciCke = 0;
  reg [7:0] ciN = 0;
  reg [31:0] ciValueA = 'hffff;
  reg [31:0] ciValueB = 0;
  wire [31:0] ciResult = 0;
  wire ciDone;

  busErrorCounter #(
      .CUSTOM_INSTRUCTION_ID(CUSTOM_INSTRUCTION_ID)
  ) bec (
      .reset(reset),
      .systemClock(sysClock),
      .busErrorIn(busError),
      .ciStart(ciStart),
      .ciCke(ciCke),
      .ciN(ciN),
      .ciValueA(ciValueA),
      .ciValueB(ciValueB),
      .ciResult(ciResult),
      .ciDone(ciDone)
  );
  
  always begin
    #5 sysClock = ~sysClock;
  end


  localparam CI_A_READ = 0;
  localparam CI_A_RESET = 1;

  task getBusErrorCounter;
    begin
      @(posedge sysClock) #0 ciStart = 1;
      #0 ciCke = 1;
      #0 ciN = CUSTOM_INSTRUCTION_ID;
      #0 ciValueA = CI_A_READ;
      #0 ciValueB = 32'h0;
      @(posedge sysClock) #0 ciStart = 0;
      #0 ciN = 0;
      #0 ciCke = 0;
      #0 ciValueA = 0;
      #0 ciValueB = 0;
    end
  endtask

  task resetBusErrorCounter;
    begin
      @(posedge sysClock) #0 ciStart = 1;
      #0 ciCke = 1;
      #0 ciN = CUSTOM_INSTRUCTION_ID;
      #0 ciValueA = CI_A_RESET;
      #0 ciValueB = 32'h0000ABCD;
      @(posedge sysClock) #0 ciStart = 0;
      #0 ciN = 0;
      #0 ciCke = 0;
      #0 ciValueA = 0;
      #0 ciValueB = 0;
    end
  endtask


  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_busErrorCounter);
    reset = 1;
    #5
    reset = 0;
    getBusErrorCounter();
    #50
    getBusErrorCounter();
    @(posedge sysClock)
    busError = 1;
    @(posedge sysClock)
    busError = 0;
    getBusErrorCounter();
    @(posedge sysClock)
    busError = 1;
    #50
    @(posedge sysClock)
    busError = 0;
    getBusErrorCounter();
    #5
    resetBusErrorCounter();
    getBusErrorCounter();
    #10 $finish;
  end

endmodule
